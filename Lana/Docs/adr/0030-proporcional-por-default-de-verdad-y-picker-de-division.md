# ADR-0030: El proporcional por default de verdad, y el picker de división fuera de Compartido

- **Estado:** Aceptada
- **Fecha:** 2026-08-28

## Contexto

ADR-0028 construyó el split proporcional derivado de los ingresos de la
lista y lo declaró el default. En la práctica no lo era. El usuario:
"al momento de que registro un gasto compartido, pues no me da la opción de
poner cómo dividirlo, además, veo que por default se pone mitad y mitad,
pero no, yo quiero que se ponga la opción proporcional por default".

Tres huecos, los tres míos:

1. **`CreateSharedListModel` nunca pedía ingresos** y fijaba
   `defaultSplit: .equally(...)` a fuerza. ADR-0028 agregó la captura de
   ingresos solo a la pantalla de **editar**, así que una lista creada por
   el camino normal no podía dividir proporcionalmente hasta que alguien
   fuera a editarla — y nada en la app sugería hacerlo. Ese es el "por
   default se pone mitad y mitad" que se veía.
2. **`SharedExpenseMatch.resolvedSplit` caía a `list.defaultSplit`, no a
   `preferredSplit`.** Construí `preferredSplit` en ADR-0028 precisamente
   para esto y luego no lo usé en el camino que más se usa: capturar por
   voz caía siempre en el default guardado aunque la lista sí tuviera los
   ingresos.
3. **Ninguna de las dos superficies personales dejaba elegir la regla.**
   ADR-0027 puso lista y pagador en el editor del Dashboard, y ADR-0029 el
   desglose, pero la regla era de solo lectura en ambos — documenté esa
   frontera como deliberada ("se ajusta desde la lista misma"), y era
   demasiado estrecha: cambiar entre proporcional y mitad y mitad no
   necesita el formulario numérico completo.

## Decisión

**1. Los ingresos se piden al crear la lista, no solo al editarla.**
`CreateSharedListModel` gana `participantIncomes` (paralelo a
`participantNames`, texto, vacío válido) y calcula el `defaultSplit` como
`proportionalSplitFromIncomes ?? .equally(...)`. Una lista nueva con
ingresos nace proporcional.

**2. `resolvedSplit` usa `preferredSplit`.** Un `splitHint` explícito en el
texto ("mitad y mitad") sigue ganando — lo que el usuario dice manda sobre
el default de la lista; lo que cambia es a qué se cae cuando no dijo nada.

**3. `SplitRuleKind` baja a `LanaCore`, y las superficies personales ganan
picker.** El enum vivía en `SharedFeature` (`SharedSplitRuleKind`), donde
`EntryFeature`/`DashboardFeature` no pueden verlo. Ahora vive en `LanaCore`
con `displayName`, `needsPerParticipantInput`, `init(_ split:)` y —lo
importante— `resolve(in list:)`, que devuelve la regla concreta que la
lista puede armar **sola**: `.equally` y `.payerOnly` siempre,
`.proportional` solo si hay ingresos, `.percentage`/`.exactAmounts` nunca.
`resolvable(in:)` es lo que los pickers ofrecen.

`.proportional` va **primero** en `allCases`, así que encabeza el picker
donde esté disponible — el orden de declaración es la señal de cuál es el
default deseado, y hay un test que lo fija para que no se reordene por
accidente.

`SharedFeature` conserva la copia específica de su formulario (`helpText`,
`fieldPlaceholder`) como una extensión sobre el tipo de `LanaCore`: es el
único que captura números por participante y necesita explicarlos.

La frontera se mueve, no desaparece: `.percentage`/`.exactAmounts` siguen
siendo exclusivos del formulario completo de Compartido, porque piden un
número por persona y duplicar ese formulario en un editor que Tarjetas
también usa sí metería conceptos de "compartido" donde no van.

## Consecuencias

**Bueno:**

- Una lista nueva con ingresos divide proporcional desde el primer gasto,
  por cualquiera de los tres caminos de captura.
- Cambiar entre proporcional y partes iguales se hace donde surge la duda,
  sin ir a la pestaña de Compartido.
- Una sola definición de "las formas de dividir", en vez de una en
  `SharedFeature` invisible para los otros dos módulos.

**Malo / a vigilar:**

- **Las listas que ya existen siguen con su `defaultSplit` guardado.** Este
  cambio no migra nada: una lista creada antes sigue en partes iguales
  hasta que se le capturen los ingresos desde "Editar lista". Es
  deliberado —reescribir el split de listas existentes cambiaría cómo se
  dividen los gastos futuros de alguien sin pedírselo— pero significa que
  el usuario tiene que ir a editar sus listas actuales una vez.
- El picker de las superficies personales muestra 2 o 3 opciones según la
  lista tenga ingresos o no. Una opción que aparece y desaparece es
  confusa si no se sabe por qué; el footer de "Editar lista" lo explica,
  pero el picker mismo no.
- `SplitRuleKind.resolve(in:)` devolviendo `nil` para
  `.percentage`/`.exactAmounts` mezcla dos razones distintas de "no se
  puede resolver": "esta regla nunca se autoresuelve" y "esta lista no
  tiene los datos". Hoy ambas se tratan igual (no se ofrece), pero si
  alguna vista necesitara distinguirlas tendría que separarse.
