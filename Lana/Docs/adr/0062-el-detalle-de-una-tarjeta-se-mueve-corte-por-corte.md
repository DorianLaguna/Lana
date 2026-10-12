# ADR-0062: Mover el detalle de una tarjeta corte por corte, dejando los saldos en hoy

- **Estado:** Aceptada
- **Fecha:** 2026-10-12
- **Relacionada:** ADR-0060 (el crédito cuenta en el mes en que cierra su ciclo),
  ADR-0047 (el formato de fechas vive en `LanaCore`), ADR-0014

## Contexto

El detalle de una tarjeta mostraba **solo los cargos del ciclo de corte vigente**:
`CardDetailModel.onAppear(asOf:)` le pedía a `ExpenseStore` exactamente
`(cycle.start, cycle.end]` y no había estado de periodo. Lo comprado antes del
último corte seguía registrado pero desaparecía de la pantalla, y no había desde
dónde consultarlo.

El dueño lo reportó entrando a "lo que gasté en mis tarjetas": aparecían solo los
movimientos posteriores al corte y quería ver también los anteriores. Es la misma
queja que ADR-0060 ya había registrado para la lista de Mes —*"el dueño no
encontraba sus compras: lo hecho después del corte desaparecía del mes en que se
hizo"*— del otro lado del corte.

Las fuerzas en tensión:

- **Encontrar una compra** pide historia continua y búsqueda por fecha.
- **Entender la deuda** pide cortes separados: el ciclo es la unidad que el banco
  factura, y la distinción entre "lo que vence ya" y "lo que cae el mes que entra"
  es, según `CONVENTIONS.md`, la que hace útil toda la función.
- Los dos saldos de una tarjeta —actual y al corte— se calculan distinto y
  `CONVENTIONS.md` prohíbe usarlos indistintamente.

Alternativas consideradas:

- **Un historial continuo sin cortes**, agrupado solo por día, cargando hacia
  atrás con el scroll. Es lo mejor para encontrar una compra y lo peor para
  entender la deuda: borra justo la frontera que le da sentido a la pantalla.
  Descartada por el dueño: quiere cada corte completo y por separado.
- **Un listado continuo con separadores de corte.** Conserva la noción de ciclo
  sin perder el scroll, pero el desglose "En qué usas esta tarjeta" dejaría de
  tener un periodo al que referirse, y es la mitad de la pantalla.
- **Hacer que el encabezado siga al periodo** (mostrar "Debes en total" del corte
  navegado). Coherente al navegar, y descartada: "Debes en total" de hace tres
  cortes es un número que nadie puede usar y que se confunde con deuda real, que
  es exactamente el error que `CONVENTIONS.md` marca como el clásico.
- **Etiquetar el periodo con su rango de días** ("del 13 de septiembre al 12 de
  octubre"). Es lo más explícito y es **falso** hoy: ver más abajo.

## Decisión

**El desglose y la lista siguen un corte seleccionable; los saldos del encabezado
siempre son los de hoy.**

- Un `CycleSelector` (`‹ Corte del 12 de octubre ›`) gobierna de ahí para abajo:
  "En qué usas esta tarjeta" y la lista de movimientos. Arriba de él, "Debes en
  total", "Para el corte", "Después del corte" y la barra de límite **no se
  mueven**: son deuda vigente y se siguen derivando de `CardLedger` con `asOf:`
  hoy. No se "arreglan" para seguir al selector.
- El corte seleccionado vive en `CardDetailModel`, no en la vista:
  `CardsModel.makeCardDetailModel(for:)` reutiliza la instancia y
  `navigationDestination` se recalcula en cualquier redibujado. Un refresco tras
  editar o borrar un gasto (`refreshCurrentCardDetail()`) **conserva** el corte.
- **Los topes son reales.** Hacia adelante, el corte vigente. Hacia atrás, el
  corte del cargo más viejo registrado: antes de eso no hay cortes vacíos que
  recorrer, hay cortes que Lana no vivió (ADR-0060 ya advierte que el primer ciclo
  de una tarjeta que empezó antes de Lana solo trae lo que se registró). La flecha
  se apaga pero no se quita, para que la etiqueta del centro no brinque.
- **El detalle carga toda la historia de la tarjeta de un jalón y rebana en
  memoria.** `CoreDataExpenseStore.expenses(in:)` decodifica el log completo de
  eventos y filtra el rango en Swift pase lo que pase, así que pedir un ciclo
  cuesta lo mismo que pedir todo. A cambio, moverse de corte no vuelve a tocar el
  store y es sincrónico: sin spinner y sin `Task` en la vista.
- **La pertenencia a un corte la decide siempre `StatementCycle.contains(_:)`**, no
  el rango que se le pidió al store: el ciclo es `(start, end]` y
  `DateInterval.contains` incluye los dos extremos. Con un solo ciclo en pantalla
  casi no se notaba; mostrando varios, un cargo en la medianoche del corte saldría
  en dos cortes distintos.
- **La etiqueta nombra el día en que el corte cierra, no el rango de días que
  abarca.** Un ciclo es `(start, end]` con `end` a la medianoche del día de corte,
  así que un cargo de ese mismo día a las 3 pm cae en el ciclo **siguiente**.
  Cualquier rango escrito quedaría corrido un día respecto a lo que la pantalla de
  verdad lista, o respecto a lo que el dueño cree: ADR-0060 dice "con corte el 23,
  lo que compra el 24 ya es del mes siguiente", o sea que para él el 23 todavía es
  de este corte. Mientras esa pregunta no se resuelva, la etiqueta no opina.
- **`recordPayment` recarga con el "ahora" de la pantalla, no con la fecha del
  pago.** Registrar un pago fechado en el pasado movía ahí los saldos; con un
  selector encima habría movido también cuál es el corte vigente.

`StatementCycle` gana `previous(cutoffDay:calendar:)` y `next(cutoffDay:calendar:)`,
resueltos pidiendo el ciclo que contiene el día anterior a `start` o el posterior a
`end` —el mismo camino que ya usaba `CardLedger.lastStatementBalance`— y no
sumándole meses a las fechas que ya tiene. Así el día de corte se vuelve a derivar
con `min(cutoffDay, daysInMonth)` en cada mes, y un corte 31 va 31 → 28 → 31 en vez
de quedarse pegado al 28 al salir de febrero. El `cutoffDay` se pasa en cada
llamada y no se guarda en el struct, porque `CardLedger` construye
`StatementCycle(start:end:)` para una ventana de pagos que no es un ciclo y
cargarle un `cutoffDay` sería mentir.

## Consecuencias

- Encontrar una compra vieja con esta tarjeta son N taps, uno por corte: un año son
  doce. No hay salto directo a un mes ni búsqueda por fecha. Es aceptable porque el
  dueño busca compras recientes; si pide más, el siguiente paso es un selector de
  mes, no agrandar este.
- El encabezado y la lista pueden contradecirse a la vista: "Para el corte $3,400"
  arriba y una lista de hace tres cortes abajo. Es deliberado y es el riesgo
  principal de esta pantalla. Lo sostiene que el selector está **debajo** de todo
  el bloque de saldos, de modo que se lea como "de aquí para abajo manda el corte".
- La etiqueta no dice qué días abarca el corte, que es la pregunta que más confunde
  de una tarjeta. Los días sí se ven en los encabezados de la lista.
- **El día del corte está corrido un día** respecto al modelo mental del dueño:
  hoy un cargo del día de corte cuenta en el ciclo que abre, no en el que cierra.
  Este ADR **no lo cambia** —mueve dinero en Hoy, en Mes (`BudgetMonth`), en la
  proyección (`MonthCommitments`) y en la ventana de pagos de `CardLedger`, y pide
  la firma del dueño— pero lo deja escrito y evita que el copy lo afirme. Es la
  deuda más grande que queda abierta aquí.
- Un cargo fechado más allá del cierre del corte vigente no se carga ni se alcanza
  con la flecha de adelante, igual que antes de este cambio. Si aparece el caso, la
  salida no es ampliar el rango: es decidir si el corte vigente puede adelantarse.
- Cargar toda la historia por tarjeta es gratis **hoy** porque el store pliega el
  log completo en cualquier consulta. Si `expenses(in:)` algún día se vuelve una
  consulta indexada de verdad, este detalle pasa de gratis a ser el peor cliente
  del store y hay que volver a pedir por ciclo.
- Una tarjeta de débito no muestra selector: no tiene `cutoffDay`. Sigue sin
  mostrar movimientos, que es un hueco anterior y distinto.

## Qué haría reconsiderar esto

- Que el dueño empiece a buscar compras de hace medio año: ahí doce taps ya no
  alcanzan y conviene un selector de mes o búsqueda por fecha.
- Que se decida que el día del corte cuenta en el ciclo que cierra: cambia
  `StatementCycle.contains`, y entonces la etiqueta sí puede decir el rango de días.
- Que `ExpenseStore` gane consultas indexadas por tarjeta y fecha: cargar toda la
  historia dejaría de ser gratis.
- Que aparezca un saldo real del banco: el encabezado dejaría de derivarse de lo
  registrado y la contradicción con la lista se leería distinto.
