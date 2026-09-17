# ADR-0056: El monto se teclea en un campo propio, alineado a la derecha

- **Estado:** Aceptada
- **Fecha:** 2026-09-17
- **Relacionada:** ADR-0044 (sistema de diseño), ADR-0047 (el formato vive en
  `LanaCore`)

## Contexto

Los seis campos de monto de la app —editar un gasto, el borrador de la captura, un
gasto compartido, un recurrente, un pago de tarjeta y el límite de una tarjeta—
usaban `TextField("0", value:format: .number)`. Con el monto en cero el campo
muestra un `0`, y al tocarlo el cursor cae **a la izquierda** de ese cero: los
dígitos entran antes, y hay que mover el cursor a mano hasta el otro lado. El
usuario lo reportó como incómodo de hacer con una sola mano.

`TextField(value:format:)` tiene además otros filos conocidos: reformatea mientras
se escribe (un separador de miles aparece y corre el cursor), y el texto a medio
teclear —"12."— no es un número válido, así que el binding se pelea con lo que se
ve.

## Decisión

**Un componente propio, `AmountField` (`LanaDesign`), para todo monto tecleable.**

- **Cero se muestra como campo vacío**, con "0" de marca de agua. Sin un cero que
  estorbe, el cursor arranca donde arrancan los dígitos.
- **Alineado a la derecha**, siempre, como las cifras del resto de la app.
- **Se escribe sobre texto, no sobre un número**: el campo deja pasar dígitos y un
  separador decimal, y de ahí sale el `Decimal`. "12." es un texto válido a medio
  teclear, y no se reformatea nada mientras se escribe.
- La coma es decimal o de miles según el resto del texto: con un punto presente
  ("1,250.50") son miles; sin él ("12,5") es el decimal, que es lo que dan los
  teclados de otras regiones.
- El monto también cambia desde fuera ("Pagar todo" precarga el corte, el parser
  corrige un borrador): el texto sigue al valor cuando eso pasa.

Escribir un monto es entrada, no formato de salida: `Money.formatted()` y
`MoneyDisplay` (ADR-0047) siguen siendo los que escriben montos ya guardados.

## Consecuencias

- Teclear un monto se siente igual en las seis pantallas, y se puede hacer con una
  mano.
- **No hay separador de miles mientras se escribe.** Un monto largo se ve
  "1250.50" hasta que se guarda. Es el precio de no mover el cursor mientras se
  teclea.
- `AmountField` guarda el texto en su propio `@State`, así que el valor y lo que se
  ve pueden separarse un instante si alguien cambia el binding en medio de una
  tecla. Se sincroniza en el `onChange`, no antes.

## Qué haría reconsiderar esto

- Que alguien capture montos en miles seguido y extrañe el separador. La salida
  sería formatear al perder el foco, no mientras se escribe.
