# ADR-0027: Compartir un gasto es una señal explícita del texto, y siempre reversible

- **Estado:** Aceptada
- **Fecha:** 2026-08-28

## Contexto

ADR-0025 conectó la captura general (voz/texto) con las listas compartidas
usando `payerHint` como única señal: si el modelo decía quién pagó, se
intentaba resolver contra una lista real. En producción eso mandó
**todos** los gastos personales a la lista compartida. El usuario lo
reportó: "en todos los gastos parece que se está compartiendo, y pues no
debe ser así".

La cadena exacta del fallo, toda mía:

1. El `@Guide` de `payerHint` decía llenarlo con `'yo' si dice que lo pagó
   solo` — y casi cualquier frase de gasto dice eso ("pagué la gasolina",
   "compré despensa"). El modelo lo llenaba casi siempre.
2. La guardia determinista de `ParsingPipeline` exentaba `"yo"` del
   chequeo de "¿aparece literal en el texto?" — precisamente porque no
   aparece literal. Así que nunca se descartaba.
3. `SharedExpenseMatch.bestMatch` resolvía `"yo"` contra la identidad
   marcada en la lista (ADR-0022). Con **una sola** lista, eso es siempre
   un match único, nunca ambiguo.

Mi propio test (`'yo' resuelve contra la identidad marcada`) documentaba el
bug como comportamiento correcto: pasaba con un `payerHint` de `"yo"` y sin
ninguna mención de compartir. Modelé la pregunta equivocada — construí la
detección sobre "¿quién pagó?" cuando lo que decide es "¿esto se comparte?".
Son cosas distintas y confundirlas mueve dinero entre personas sin que
nadie lo pida.

## Decisión

**1. `isShared` es la señal, y el texto crudo tiene la última palabra.**

`ParsedTransaction` gana `isShared: Bool`, con un `@Guide` que dice
explícitamente que decir quién pagó NO es compartir y da ejemplos de gasto
personal normal. `payerHint`/`splitHint` pasan a estar condicionados a él y
no significan nada por su cuenta.

Pero el `@Guide` no basta — ya falló una vez. `ParsingPipeline` agrega una
guardia determinista: si `isShared` viene en `true` pero el texto crudo no
contiene vocabulario de compartir ("compart", "dividi", "repart", "a
medias", "mitad y mitad", "entre los dos", "cada quien", "me debe", "le
debo"), se anula junto con `payerHint`/`splitHint`. Es el mismo principio
que ya rige el monto (Docs/CLAUDE.md → "el regex gana sobre el modelo"),
aplicado a la decisión más cara del sistema.

La lista de marcadores es corta y explícita a propósito: **prefiere no
detectar** un gasto compartido (el usuario lo marca a mano, que ahora se
puede en dos lugares) antes que mandar un gasto personal a una lista. Los
dos errores no cuestan lo mismo.

**2. Un gasto puede moverse entre personal y compartido, en los dos
sentidos, sin borrarse.**

Esto no era expresable: en `ExpenseCorrected`, `nil` significa "conserva lo
anterior", así que no había forma de decir "quítale la lista" — y
`sharedListID` ni siquiera existía en el tipo, `ResolvedTransaction.applying`
siempre conservaba el del evento raíz.

`ExpenseCorrected` gana `sharedListID` (para mover a una lista o cambiar de
lista) y `clearsSharedContext: Bool` (para volverlo personal). La bandera
explícita existe justamente porque `nil` ya está tomado por otra semántica;
sin ella habría que borrar el gasto y recapturarlo, que es perder el
historial de algo que solo estaba mal clasificado.

`CoreDataExpenseStore.save(_:)` lo deduce solo: si el gasto vigente tenía
lista y el que llega no trae ninguna, emite `clearsSharedContext`. Así el
protocolo `ExpenseStore` no cambia — mover un gasto sigue siendo
`save(_:)`, igual que cualquier otra corrección.

Dos entradas en la UI, cada una donde el usuario ya está:

- **Desde la lista compartida** (`SharedExpenseCaptureView` en modo
  edición): "Quitar de esta lista", junto a "Borrar gasto" pero separado de
  él, con una nota de que conserva el gasto. Es lo que permite limpiar los
  gastos que el bug de arriba metió por error.
- **Desde el Dashboard** (`EditExpenseView`): una sección "Compartido" con
  un picker de lista ("Personal" + las listas) y, si hay lista, el
  pagador. La regla de división **no** se edita ahí: se toma de la lista
  (`preferredSplit`) y se ajusta desde la lista misma, que ya tiene la UI
  de las 5 reglas. Duplicarla metería conceptos de "compartido" en un
  editor que Tarjetas también usa.

## Consecuencias

**Bueno:**

- Un gasto personal ya no puede acabar en una lista compartida sin que el
  texto lo diga; y si la detección se equivoca, se corrige en dos toques
  sin perder el gasto.
- El historial queda íntegro: mover un gasto es una corrección más, no un
  borrado y recaptura.

**Malo / a vigilar:**

- El vocabulario de compartir es una lista fija en español mexicano. Una
  forma de decirlo que no esté ahí ("lo pagamos entre Ana y yo" sin más)
  no se detecta — el gasto se guarda personal y hay que moverlo a mano. Es
  el error barato a propósito, pero si aparecen formas comunes que faltan,
  se agregan ahí.
- `clearsSharedContext` es una bandera con precedencia especial dentro de
  `applying(_:)`: gana sobre `sharedListID`/`payer`/`split` de la misma
  corrección. Si algún día se emite una corrección con la bandera **y**
  una lista nueva, la bandera manda y la lista se ignora en silencio. Hoy
  nadie construye eso (el store las hace excluyentes), pero el tipo lo
  permite.
- `CoreDataExpenseStore.save(_:)` ahora pliega todos los eventos para
  saber si el gasto estaba compartido, en cada guardado de un gasto que ya
  existía. Es trabajo extra proporcional al log completo; con volúmenes
  reales de esta app es despreciable, pero es un `O(eventos)` que antes no
  estaba en la ruta de escritura.
- La detección sigue sin estar medida contra el golden set — la nota de
  ADR-0025 sigue vigente, y ahora hay más superficie que medir (`isShared`
  además de `payerHint`/`splitHint`).
