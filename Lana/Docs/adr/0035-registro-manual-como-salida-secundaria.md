# ADR-0035: Aceptar un segundo camino de captura, manual y explícitamente secundario

- **Estado:** Aceptada
- **Fecha:** 2026-09-07

## Contexto

Hasta ahora Lana sostenía que **no hay un segundo camino de captura**: la voz
(ADR-0015) y el OCR de tickets (ADR-0010) son formas de producir texto que
alimentan el mismo parser, y Apple Pay (ADR-0009) también termina en él. Un solo
parser, un solo camino, un solo lugar donde arreglar bugs de interpretación.

Eso deja tres huecos reales:

1. **Sin Apple Intelligence no se puede registrar nada.** `EntryModel.onAppear()`
   consulta `parser.availability` y, si no está disponible, la pantalla de captura
   se reemplaza entera por `AvailabilityOnboardingView`. En un dispositivo sin
   Apple Intelligence, o con el modelo todavía descargándose, la app no permite
   registrar un gasto por ningún medio.
2. **Dictar no siempre es opción.** En una junta, en transporte público, con ruido
   — el único botón de captura de la app es un micrófono.
3. **El parser puede equivocarse en algo que el usuario ya tenía claro.** Corregir
   un borrador mal parseado cuesta más que teclear los cuatro campos.

Las alternativas consideradas:

- **Un campo de texto que alimente el parser.** `EntryModel.inputText` y `submit()`
  ya soportan texto tecleado; solo falta un `TextField` conectado. Es la opción más
  barata y no rompe la regla del parser único. Pero no resuelve el hueco 1 (sin
  modelo no hay parseo) ni el 3 (sigue habiendo una interpretación de por medio), y
  teclear una frase en lenguaje natural para que un modelo la desarme no es más
  rápido que llenar los campos.
- **Un formulario nuevo dedicado a la captura manual.** Resuelve los tres huecos,
  pero deja dos formularios de gasto en la app — el nuevo y `EditExpenseView` — que
  hay que mantener en paralelo cada vez que se agregue un campo.
- **Hacer del formulario la captura principal, con la voz como acelerador.**
  Contradice el porqué del proyecto (Docs/CLAUDE.md: "cuando dudes entre dos
  opciones, gana la que quita fricción de la captura"). El usuario abandonó otras
  apps justamente por lo tedioso de capturar en formularios.

## Decisión

Existe un **segundo camino de captura, manual, que no pasa por el parser**, y es
deliberadamente secundario:

- Se llega por un `+` en el toolbar del Dashboard. El micrófono flotante de 76pt
  sigue siendo el camino principal y el centro visual de la app; el `+` es chrome
  de barra de navegación, del mismo peso que el `+` de Tarjetas.
- Es el formulario que ya existe, no uno nuevo: `EditExpenseModel`/`EditExpenseView`
  ganan un `Mode` (`.creating` / `.editing`). Los campos, el dropdown de
  subcategorías y la sección de compartido (ADR-0027/0029/0030) son literalmente los
  mismos, así que no pueden desincronizarse.
- Lo capturado a mano entra con **`needsReview = false`**. La regla de
  Docs/CLAUDE.md ("todo lo capturado automáticamente entra con `needsReview`") es
  sobre lo que la app infirió; aquí no hay inferencia, lo escribió el usuario campo
  por campo.
- El formulario gana un picker de **método de pago**, que no tenía. Sin él, un gasto
  registrado a mano no podría apuntar a una tarjeta y no alimentaría la deuda por
  tarjeta ni la proyección — que es media app. El picker **no ofrece "sin
  especificar"**: sería una opción imposible de cumplir, porque
  `ExpenseAdded.paymentMethod` no admite `nil` (al crear se guardaría como efectivo)
  y en `ExpenseCorrected` el `nil` significa "no cambies esto" (al editar no haría
  nada). Todo gasto guardado ya trae uno; el `nil` de `Expense.paymentMethod` solo
  existe para los ingresos, donde el picker ni se muestra.
- Guardar se deshabilita mientras el formulario nuevo esté en $0. La garantía de
  "guardar nunca se bloquea" cubre un parseo ambiguo que sí trae información
  rescatable; un formulario en blanco no tiene nada que rescatar.

## Consecuencias

**Buenas**

- Registrar un gasto deja de depender de Apple Intelligence. En un dispositivo sin
  el modelo, la app pasa de inservible a usable.
- El `+` es la única superficie de captura que no puede fallar: no pide permisos, no
  espera a que un modelo cargue, no interpreta nada.
- Corregir con qué tarjeta se pagó un gasto que entró mal por Apple Pay ahora es
  posible desde el mismo editor — antes el método de pago no se podía editar en
  ningún lado.
- Alimenta el vocabulario igual que la captura por voz: elegir una categoría a mano
  registra `concepto → categoría` (ADR-0012).

**Malas — el costo que se está pagando**

- **La afirmación "hay un solo camino de captura" ya no es cierta.** Un cambio en el
  modelo de datos de una transacción ahora tiene dos lugares que revisar
  (`DraftTransaction.asExpense()` y `EditExpenseModel.save()`), no uno. La regla que
  sí se mantiene, y que no se debe romper, es la de **un solo parser**: nada de esto
  interpreta texto.
- **Dos editores de transacción con capacidades distintas.** `DraftCard`
  (EntryFeature) deja quitar un gasto de una lista compartida pero no asignarlo a
  una; `EditExpenseView` sí deja asignarlo pero no muestra el aviso de detección
  automática. Ya eran distintos antes; ahora la diferencia es más visible porque
  ambos son puntos de alta.
- **Riesgo de que el formulario gane peso.** Cada campo nuevo que alguien quiera
  "que también esté al capturar" empuja hacia el formulario tedioso que el usuario
  abandonó en otras apps. Si el `+` empieza a usarse más que el micrófono, la
  decisión que hay que revisitar no es esta: es por qué la captura por voz está
  fallando.

**Qué haría reconsiderar esto**

- Que Apple Intelligence deje de ser opcional en el hardware soportado: el hueco 1
  desaparece y el `+` queda solo como comodidad.
- Que el `+` se vuelva el camino dominante en uso real. Eso no querría decir
  ascenderlo a principal, sino que el micrófono no está cumpliendo — y eso se
  arregla en el parser o en la captura por voz, no aquí.
