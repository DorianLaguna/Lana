# ADR-0054: Una fila del plan se paga entera, y pagarla la cierra

- **Estado:** Aceptada
- **Fecha:** 2026-09-17
- **Relacionada:** ADR-0053 (cada quien paga o cobra su saldo), ADR-0005 (eventos
  append-only)

## Contexto

Con el plan de ADR-0053, marcar una deuda como pagada abría una hoja para teclear
el monto y la fecha. Dos problemas, los dos reportados por el usuario:

1. **El monto sobra.** Una fila del plan ya es lo que falta entre esas dos
   personas; se paga completa. Teclearlo otra vez es trabajo que no decide nada.
2. **Pagar una fila no la cerraba.** El plan se recalculaba desde el saldo: si
   Evan te pagaba sus $66.84, su saldo bajaba a $55.38 y *ese resto se repartía de
   nuevo entre todos los que cobran*, así que volvía a aparecer una fila de Evan
   hacia ti por unos $30. Desde fuera se ve como que "sigue debiendo" después de
   haber pagado justo lo que la app pidió.

El segundo es el de fondo: un plan que se rearma completo después de cada pago no
tiene filas estables, y sin filas estables el botón de "ya pagó" no significa nada.

## Decisión

**El plan se arma una sola vez sobre los gastos, y a cada fila se le resta lo que
ese par ya se liquidó.** El reparto proporcional (ADR-0053) se calcula sobre los
saldos *sin* liquidaciones; después, cada `SettlementRecorded` se descuenta de la
fila de ese par, y lo que sobre (si pagó de más de lo que esa fila pedía) se
descuenta de las otras filas de quien pagó, de mayor a menor. Pagar una fila la
cierra y deja las demás iguales.

**El botón registra el pago completo de la fila, sin hoja ni teclado.**
`SettleUpView` se borra.

**Si el resultado deja de cuadrar con los saldos** —alguien pagó de más, o le pagó
a quien no le tocaba— el plan se rearma desde el saldo vigente, como en ADR-0053.
Pierde la correspondencia fila a fila, pero nunca muestra un plan que no salde.

## Consecuencias

- El botón hace lo que dice: la fila desaparece y los saldos se mueven.
- **No se puede registrar un pago parcial desde la lista.** Quien pague la mitad no
  tiene dónde decirlo; la fila sigue completa hasta que pague el resto. Si hace
  falta, la salida es un gesto secundario ("pagó otra cantidad"), no volver a
  preguntar el monto en cada pago.
- **No hay deshacer.** Un toque por error registra un pago que solo se corrige
  registrando el pago inverso, y eso todavía no tiene UI.
- El plan depende ahora del historial de liquidaciones, no solo del saldo: dos
  listas con los mismos saldos pueden mostrar filas distintas según cómo se
  pagaron. Es a propósito — es lo que hace que una fila pagada se quede pagada.
