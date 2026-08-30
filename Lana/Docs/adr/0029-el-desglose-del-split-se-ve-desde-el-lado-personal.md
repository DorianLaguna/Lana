# ADR-0029: El desglose de un gasto compartido se ve también desde el lado personal

- **Estado:** Aceptada
- **Fecha:** 2026-08-28

## Contexto

Desde ADR-0022, un gasto compartido cuenta en el Dashboard personal solo
por la parte que le toca a quien mira (`Expense.personalAmount`), no por su
total. Correcto para las sumas, pero la única explicación visible de por
qué el número era distinto al que se capturó era un ícono de `person.2` en
la fila — cuyo propio comentario en `TransactionRow` decía que "solo
explica por qué", asumiendo que el resto ya se entendía.

No se entendía. El usuario lo reportó: "para la revisión o al ver los
detalles de los gastos compartidos en mi lista personal, no veo cómo se
divide el pago". Y tenía razón en las tres superficies:

- **La fila del Dashboard** mostraba `$400` en un gasto de `$800`, sin
  decir de cuánto era. Se lee como un gasto de $400.
- **El editor de un gasto ya guardado** (ADR-0027 le agregó lista y
  pagador) decía a qué lista va y quién pagó, pero no cuánto acaba
  tocándole a cada quien.
- **La revisión antes de confirmar una captura** (`DraftCard`) tenía el
  mismo hueco, que es peor ahí: es el momento de verificar una detección
  automática, y no se podía verificar lo único que importa.

Todo el cálculo existía (`SplitRule.portions(of:)`, desde ADR-0007) pero
solo se dibujaba dentro de la feature de Compartido.

## Decisión

**El cálculo vive en `LanaCore`, probado una vez; cada feature solo lo
dibuja.** `Expense.splitShares() -> [SplitShare]?` devuelve cuánto le toca
a cada participante, con quien pagó primero y marcado. `nil` cuando el
gasto no es compartido **o cuando el split guardado no resuelve** — un
reparto inválido se muestra sin desglose, nunca con uno inventado.

`.payerOnly` es el caso especial, igual que en `personalAmount`:
`portions(of:)` regresa vacío porque nadie le debe nada a nadie, pero para
mostrarlo sí importa decir que el total le tocó a quien pagó.

`SplitRule.displayName` también baja a `LanaCore` — tres pantallas de dos
módulos distintos lo necesitan y las features no se importan entre sí
(mismo criterio que `SuggestedCategory.displayName`). `SharedSplitRuleKind`
(SharedFeature) conserva el suyo: es el nombre corto del picker de 5
opciones, con otro propósito.

Las tres superficies:

- **`TransactionRow`** gana un slot genérico `secondaryAmountText`, y
  `DaySectionListView` le pasa "de $800.00". Solo cuando el total difiere
  de tu parte: si lo pagaste tú y nadie más debe, repetirlo sería ruido.
  `LanaDesign` sigue sin conocer el dominio — recibe un `String?`, no un
  `SplitRule`.
- **`EditExpenseView`** muestra la regla y el reparto participante por
  participante, calculado con el **monto y la regla vigentes del
  formulario**, no los guardados: editar el monto actualiza el desglose
  antes de guardar.
- **`DraftCard`** lo mismo, sobre `DraftTransaction.splitShares`.

## Consecuencias

**Bueno:**

- La pregunta "¿por qué este gasto dice $400 si fueron $800?" se contesta
  sin salir de la pantalla donde surge.
- Una detección automática de gasto compartido (ADR-0027) ahora es
  verificable antes de confirmarla, no solo después de entrar a la lista.
- El reparto se calcula en un solo lugar probado; las tres vistas no
  pueden divergir.

**Malo / a vigilar:**

- El desglose en `EditExpenseView`/`DraftCard` lista a **todos** los
  participantes. Con una lista de muchas personas eso alarga bastante el
  formulario; hoy el caso real es de dos, pero si crece habría que
  colapsarlo tras un "ver desglose".
- `splitShares()` recalcula `portions(of:)` en cada render de la fila del
  formulario. Es aritmética de `Decimal` sobre pocos participantes, pero
  es trabajo dentro de `body`, no cacheado — si alguna vista lo llama
  dentro de una lista larga habría que subirlo al modelo.
- El desglose muestra lo que **toca** de cada gasto, no el saldo neto
  entre las personas. Son cosas distintas (el saldo pliega todos los
  gastos y las liquidaciones, `PersonLedger`) y nada en la UI lo aclara;
  el detalle de deuda de ADR-0024 sigue siendo el lugar para eso.
