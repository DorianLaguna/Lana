# ADR-0059: Un pago solo mueve su propia fila

- **Estado:** Aceptada
- **Fecha:** 2026-09-17
- **Revisa:** ADR-0054 (una fila del plan se paga entera, y pagarla la cierra)
- **Relacionada:** ADR-0053 (cada quien paga o cobra su saldo)

## Contexto

ADR-0054 dejó el plan anclado a los gastos, restándole a cada fila lo que ese par
ya se había liquidado. Con una lista limpia funciona. Con una lista que **ya traía
pagos registrados** —los del reparto anterior, antes de ADR-0053— no: el usuario
marcó una fila como pagada y vio que bajaban las dos filas de esa persona y que la
fila pagada seguía ahí.

Eran las dos válvulas de escape que ADR-0054 dejó abiertas:

1. **El sobrante de un pago se descontaba de las otras filas del mismo deudor.** Si
   el pago no cabía en su fila —porque un pago viejo ya la había consumido en
   parte— la diferencia se la comía la fila del otro acreedor.
2. **Si el plan dejaba de cuadrar con los saldos, se rearmaba entero desde el
   saldo.** Eso es exactamente el comportamiento que ADR-0053 y ADR-0054 querían
   quitar: todas las filas se recalculan y la que se acaba de pagar reaparece más
   chica.

## Decisión

**Un pago se descuenta solo de la fila de ese par.** Nunca toca lo que esa persona
le debe a un tercero. Si el pago es mayor que su fila, la fila queda en cero y la
diferencia no se reparte por ahí.

**Lo que quede descuadrado se parcha, no se rehace.** Se calcula la diferencia
entre los saldos vigentes y lo que el plan ya cubre, se reparte esa diferencia con
el mismo criterio proporcional de ADR-0053, y se suma al plan. Las filas que ya
estaban se quedan igual, incluidas las que un pago dejó en cero. Si el parche
produce una deuda al revés —alguien pagó de más y ahora le deben—, se netea contra
la fila contraria en vez de mostrar las dos.

Así se mantienen las dos propiedades a la vez: pagar una fila la cierra sin mover
las demás (ADR-0054), y el plan siempre suma los saldos de arriba (ADR-0053).

## Consecuencias

- Una lista con pagos viejos, de antes de este reparto, se comporta como una
  limpia: lo que no cuadra aparece como filas nuevas por la diferencia, no como un
  plan distinto cada vez.
- **Un pago de más deja de verse.** Si alguien paga más de lo que decía su fila, la
  fila queda en cero y el excedente solo se nota en que le tocará recibir algo
  después, por el parche. No hay una línea que diga "pagaste de más".
- El plan ya no depende solo de los saldos: depende también de en qué orden se
  registraron los pagos. Dos listas con los mismos saldos pueden mostrar filas
  distintas. Es el precio de que una fila pagada se quede pagada.

## Qué haría reconsiderar esto

- Que el historial de pagos "raros" crezca tanto que el parche domine al plan
  original. Ahí el plan dejaría de parecerse a los gastos, y convendría anclarlo a
  un plan guardado explícitamente en vez de recalcularlo cada vez.
