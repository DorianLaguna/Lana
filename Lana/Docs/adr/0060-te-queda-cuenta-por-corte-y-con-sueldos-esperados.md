# ADR-0060: Contar en "Te queda" la tarjeta por su corte y los sueldos que faltan por caer

- **Estado:** Aceptada
- **Fecha:** 2026-09-30
- **Reemplaza:** de ADR-0045, que "Te queda" sea ingreso registrado − gasto por
  fecha de compra; de ADR-0046, "solo cuentan las salidas" y el renglón
  "Tarjetas / Después de tarjetas"
- **Relacionada:** ADR-0046 enmienda 3 (el mes de una tarjeta lo decide su corte),
  ADR-0039 (sueldo recortado al último día del mes), ADR-0008

## Contexto

El 30 de septiembre, Hoy decía "Te queda $6,560 · Gastaste $17,439 de $24,000" y
"Te toca $6,561 al día para llegar al 30". El dueño de la app no lo reconocía:

1. **Por las tarjetas.** Él cuenta como gasto del mes lo que paga ese mes. Con
   corte el 23, lo que compra el 24 ya es del mes siguiente; al entrar a octubre
   arranca debiendo lo de esos días, y "eso está bien". Hoy lo contaba al revés:
   por fecha de compra.
2. **Por los sueldos.** Cobra $12,000 el 14 y el 30. Contando solo lo registrado,
   la primera quincena arranca en negativo aunque el dinero venga en camino.
3. **Por el cierre.** El último día no hay nada que "quedar" ni que repartir:
   es lo que se ahorró.

Alternativas consideradas:

- **Dejarlo por fecha de compra y explicarlo mejor.** Es la cuenta "correcta"
  en devengado y no duplica nada, pero no es como el dueño piensa su dinero:
  una cifra que hay que traducir cada vez no se consulta.
- **Contar los pagos a tarjeta como gasto.** Coincide con el estado de cuenta
  del banco, pero cada compra con crédito se contaría dos veces (al comprar y
  al pagar), o habría que dejar de contar las compras y perder la categoría.
- **Hacerlo preferencia** ("por compra" / "por corte", con recomendación), como
  el 50/30/20. Descartado por el dueño: lo quiere como regla fija.
- **Pedir aprobar cada recurrente en "Por revisar"** antes de contarlo. Descartado
  también: el registro automático de ADR-0042 alcanza.

## Decisión

Las tres son **reglas fijas**, no preferencias: el dueño lo decidió así.

- **Lo pagado con crédito cuenta en el mes en que cierra su ciclo**
  (`BudgetMonth`). Es la misma regla que ya decidía "para el mes que entra"
  (ADR-0046, enmienda 3), aplicada a la cifra y no solo al pie. Débito,
  efectivo, transferencia, ingresos y una tarjeta ya borrada cuentan por fecha.
  Para eso Hoy lee desde el inicio del mes anterior.
- **Los ingresos recurrentes que todavía no caen cuentan desde el día 1**
  (`MonthCommitments.expectedIncome`). Uno cuyo día ya pasó sin registrarse
  —se borró porque no llegó— deja de esperarse. Bajo la barra se dice cuánto
  de la cifra es esperado ("Incluye $24,000 que esperas el 14 y el 30."), para
  que no se lea como dinero en la cuenta. Febrero ya está cubierto: un sueldo
  del 30 cae el 28 (ADR-0039).
- **El último día y los meses pasados, la cifra dice "Ahorraste"** (o "Gastaste
  de más", sin reproche) y no hay ritmo diario.
- **El desglose ya no resta "Tarjetas".** Lo que se le debe a una tarjeta este
  mes ya está dentro de "Gastaste"; restarlo otra vez lo contaría dos veces. El
  detalle por tarjeta sigue en "Esta quincena", y "Para el mes que entra" se
  queda: es justo lo que octubre va a cargar.
- **El desglose ya no se asoma al mes siguiente.** "Y el 2 de octubre: Game
  pass" (ADR-0046) se quita: el dueño lo leyó como algo de este mes. En su
  lugar, "Para el mes que entra" cierra con el total de todas las tarjetas.
- **Mes cuenta igual que Hoy.** Su "Gastado", sus categorías, sus formas de
  pago y sus drill-downs salen del mismo conjunto
  (`DashboardModel.expenses`). Se probó primero dejar Mes por calendario y el
  dueño no reconocía un mes en el otro. Para que la lista no parezca
  incompleta, bajo la barra se dice lo que movió el corte: "Incluye $X de
  compras con tarjeta de agosto…" y "$Y … ya cuentan en octubre".
- **La lista de Mes es por fecha, y marca lo que se va.** Primero se probó
  que la lista siguiera el corte, y el dueño no encontraba sus compras: lo
  hecho después del corte desaparecía del mes en que se hizo. Ahora la lista
  trae todo lo del mes por fecha; lo que ya le cuenta al siguiente lleva
  "Para octubre" bajo el monto, apagado, y lo del mes anterior que entró en
  este corte va al final, en "De agosto, en este corte". Hoy usa la misma
  etiqueta en sus movimientos.
- **Lo que es de calendario sigue siendo de calendario**
  (`DashboardModel.calendarExpenses`): los movimientos de hoy, "Por revisar" y
  si un recurrente ya se registró.

## Consecuencias

- Una compra con tarjeta después del corte aparece dos veces en Mes: con
  etiqueta en el mes en que se hizo, y al final del siguiente. Solo suma en
  el segundo.
- El año (`YearModel`) sigue por fecha de compra: la suma de los doce meses de
  Mes puede no dar lo mismo que El año en los bordes.
- ADR-0008 decía "nunca prometas dinero que no llegó". Aquí se promete lo que
  tiene fecha y se repite cada mes, y se dice cuánto es. Si un sueldo no llega,
  se borra y deja de contar.
- El primer mes de uso subestima lo gastado: el ciclo de una tarjeta que empezó
  antes de usar Lana solo trae lo que se registró.
- Los pagos a tarjeta siguen sin contar como gasto: eso sí sería contarlo doble.

## Qué haría reconsiderar esto

- Que alguien más use la app y cuente por compra: ahí sí conviene la
  preferencia que aquí se descartó.
- Que los sueldos lleguen tarde seguido: contar lo esperado desde el día 1
  prometería dinero que no está, y habría que esperarlo solo hasta su día.
- Que aparezca un saldo real del banco (ADR-0039): la cifra dejaría de
  derivarse de lo registrado.
