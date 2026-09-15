# ADR-0039: El disponible se ancla al sueldo, y su saldo sale de lo registrado

- **Estado:** Aceptada
- **Fecha:** 2026-09-07
- **Reemplaza:** la parte de ADR-0038 que daba `disponibleProyectado` por imposible

## Contexto

ADR-0038 dejó `disponibleProyectado` fuera del catálogo de tools porque
`Projection.available(...)` recibe un `currentBalance` —el dinero real de la cuenta— y
Lana no lo tiene: no hay saldo bancario, no hay conexión al banco, y el único lugar donde
ese parámetro tenía valor era en los tests.

La observación que lo desbloqueó: **el saldo no tiene que venir del banco.** Si el usuario
registra su sueldo, lo que trae es lo que entró menos lo que gastó desde entonces. Un
sueldo ya se modela en la app: `RecurringItem` con `kind: .income` y `dayOfMonth` — su doc
comment dice literalmente "sueldo, renta, suscripciones".

Eso abrió una segunda pregunta, y es la que de verdad decide si el número sirve: **desde
cuándo se cuenta.** Con sueldo quincenal que cae el 15, la quincena de calendario 16-31
arrancaría en ceros justo después de cobrar, y el disponible saldría profundamente
negativo teniendo dinero en la mano.

## Decisión

**El periodo se ancla al sueldo, no al calendario.** `PayPeriod.current(for:recurringItems:)`
va del último ingreso recurrente al siguiente. Sin ningún ingreso recurrente configurado
cae a la quincena de calendario (1-15 y 16-fin), la misma convención que ya usa "Próximos
pagos" de tarjetas, y `isAnchoredToIncome` marca cuál de los dos se usó.

**El saldo se deriva de lo registrado:** lo que entró menos lo que salió dentro del
periodo, contando de un gasto compartido solo la parte propia (ADR-0029). A eso se le
aplican los compromisos con fecha que faltan, vía la `Projection` que ya existía y estaba
probada (ADR-0008):

- Recurrentes todavía no registrados este mes cuya fecha cae en lo que resta — un ingreso
  suma, un gasto resta.
- Pagos de tarjeta cuyo `dueDay` cae en lo que resta, por
  `outstandingStatementBalance` — la misma cifra que ya usan "Próximos pagos" y el botón
  de pagar, no una nueva.

**La cifra nunca se muestra sola.** `AvailableProjection.explanation` dice de qué está
hecha ("va de tu último sueldo al siguiente; sale de lo que registraste en Lana, no de tu
banco") y la descripción de la tool le ordena al modelo copiarla tal cual. Se consideró
pedir un saldo inicial en Ajustes y se descartó: es una preferencia que envejece sola y
que nadie actualiza, y un saldo viejo miente peor que un saldo derivado.

## Consecuencias

- `disponibleProyectado` entra al catálogo: son seis tools, no cinco. "¿Cuánto me queda de
  esta quincena?" es ahora la primera pregunta sugerida de la pantalla.
- **La cifra depende del registro, y eso no se puede esconder.** Quien no registró un gasto
  verá más de lo que tiene; quien empezó a usar Lana a medio periodo verá menos. Por eso la
  explicación es obligatoria y hay un test que verifica que la respuesta la incluya.
- **No hay arrastre entre periodos.** Lo que sobró de la quincena pasada no cuenta. Es
  conservador, que es lo que pide ADR-0008 ("el disponible siempre es conservador"), pero
  subestima a quien de verdad ahorra de una quincena a la otra.
- Se cuenta como entrada el sueldo que **todavía no llega**, si su fecha cae en el periodo.
  Suena a contradecir "nunca promete dinero que no llegó", pero es exactamente lo que
  `Docs/DATA-FLOW.md` define como proyección ("ingresos esperados − compromisos con
  fecha") y lo que `Commitment` ya permitía con montos positivos. Tiene fecha, así que
  entra.
- El periodo puede cruzar de mes (del 30 de marzo al 15 de abril). Buscar los compromisos
  solo en el mes de hoy dejaba fuera todo lo del otro lado; se miran los dos meses.
- Un sueldo configurado el 31 se recorta al último día real del mes, igual que ya hace la
  fecha límite de una tarjeta. Sin eso, desaparecería en febrero.
- Sin recurrentes de dónde sacar el periodo, la tool contesta que todavía no puede
  calcularlo. No inventa una quincena ni devuelve cero.

## Qué haría reconsiderar esto

- Que aparezca una fuente de saldo real. Ahí `currentBalance` deja de derivarse y la cifra
  se vuelve exacta en vez de conservadora.
- Que el usuario cobre de forma irregular (freelance, comisiones). El ancla por recurrente
  no le sirve, y la salida sería anclar al último ingreso **registrado**, sea recurrente o
  no — más flexible, pero también más fácil de romper con un ingreso atípico.
