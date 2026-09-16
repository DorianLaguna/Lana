# ADR-0046: "Te queda" se parte en lo que ya tiene dueño y lo que queda libre

- **Estado:** Aceptada
- **Fecha:** 2026-09-16
- **Relacionada:** ADR-0045 (la enmienda), ADR-0039 (el disponible se ancla al
  sueldo), ADR-0008 (solo cuenta lo que tiene fecha)

## Contexto

ADR-0045 dejó "Te queda" como ingreso menos gasto del mes calendario, y mandó
`AvailableProjection` —la cifra que sí descuenta compromisos— al Análisis.

El dueño de la app lo usó y dijo lo que faltaba: *"lo que te queda, eso debería
ser qué cosa, siento que debería decir cuánto va para cada cosa"*.

Tenía razón, y el problema es más grave que un dato ausente. La cifra grande
decía $12,340 cuando $11,200 ya estaban comprometidos con la renta del 30 y el
corte del día 20. No era una simplificación: era una cifra que invitaba a gastar
dinero que ya tenía dueño. Y el ritmo diario —"te toca $170 al día"— heredaba el
mismo error, multiplicado por los días que faltan.

## Decisión

La cifra héroe **sigue siendo del mes calendario**, para no romper el marco de
"día 15 de 30" ni el copy aprobado. Debajo se parte en dos: lo que ya tiene
dueño, con su desglose, y lo que queda libre.

- **El horizonte es el mes, no el periodo de sueldo.** `MonthCommitments` arma un
  `PayPeriod` con el rango del mes y llama a `commitments(from:registeredIn:asOf:)`
  y `cardCommitments(cards:ledger:asOf:)`, las mismas piezas probadas de
  ADR-0039. No se reimplementa aritmética: cambia el rango.
- **Solo cuentan las salidas.** Los constructores devuelven un sueldo por venir
  como compromiso positivo. No entra: contarlo haría que "libre" incluyera
  dinero que no ha llegado, justo lo que ADR-0008 prohíbe.
- **Lo que cae justo después del mes se ve, pero no se suma.** La renta del 1 de
  octubre, mirada el 28 de septiembre, aparece como pie —"y el 1 de octubre:
  Renta $9,000"— fuera del total. Es el agujero honesto del marco mensual: se
  nombra en vez de taparse.
- **El ritmo diario se calcula sobre lo libre.** Es el único cambio que lo vuelve
  cierto.
- **`DailyPace` gana un tercer caso.** Si lo que queda no alcanza para lo que
  viene, lo libre es negativo y repartirlo entre los días daría un absurdo. Ese
  caso no es "ya te pasaste" —todavía no se gasta de más—, es "lo que queda ya
  tiene dueño", y se dice sin reproche (Docs/CLAUDE.md → Tono).

`AvailableProjection` no cambia: sigue siendo la tool `disponibleProyectado` del
Análisis, anclada al sueldo. Son dos preguntas distintas y cada una se nombra por
su periodo, igual que ya decía ADR-0045.

### Las tarjetas se ven en dos lugares, y es a propósito

Hoy ya tenía "Esta quincena · A pagar de tarjetas". Los cortes de tarjeta también
son compromisos, así que el desglose los incluye: el mismo corte aparece en las
dos secciones.

Se planteó que el bloque nuevo se comiera esa sección. **El dueño de la app
decidió conservar las dos.** Para que el repetido se lea como intención y no como
descuido, el desglose junta las tarjetas en **un solo renglón** ("Tarjetas
· $3,200") y el detalle por tarjeta se queda donde ya estaba, en la sección que
lleva a Tarjetas.

## Enmienda 2 (2026-09-16): las tarjetas salen de lo comprometido

Al ver el bloque en el dispositivo, el dueño de la app corrigió el modelo. Lo
que había era **una sola bolsa**; lo que pidió son tres pisos, porque el dinero
de un recurrente y el de una tarjeta no salen igual:

1. **Comprometido = solo los recurrentes** que faltan por cobrarse este mes.
2. **Libre** = lo que queda del mes menos esos recurrentes.
3. **Tarjetas, aparte**, con dos cifras que nunca se suman entre sí:
   - Lo **ya facturado y sin pagar**: se paga este mes.
   - Lo del **ciclo abierto**: se factura en el próximo corte, así que se paga
     el mes que entra y **no se resta de este**.
4. **Después de tarjetas**, que **puede ser negativo**. Textual: *"debe estar
   como que voy negativo, porque le debo pagar aún a Bancomer, pero le pagaré el
   día 30 que es cuando me pagan del trabajo, y entonces ahí ya se debería
   equilibrar"*. El negativo es temporal y esperado; decirlo es el punto.

**El día de corte manda, no el día límite de pago.** El criterio que describió
—"a Bancomer le debo este mes porque su corte es el 23; a Banamex ya le pagué,
así que lo que gaste ahora es para el siguiente"— se decide con el corte. El
día límite solo dice *cuándo* dentro del mes.

**Y se corrige un defecto que escondía deuda.** `cardCommitments` exigía que el
día límite **no hubiera pasado** (`pendingOccurrence(of:after:)`), así que una
tarjeta que se seguía debiendo desaparecía del bloque justo al vencerse, que es
cuando más importa verla. Ahora lo facturado y sin pagar se muestra siempre.

**El ritmo diario se calcula sobre lo libre**, sin descontar tarjetas: la
tarjeta se paga cuando cae el sueldo, y descontarla antes diría que no hay
dinero todo el mes por algo que ya está resuelto.

## Enmiendas (2026-09-16)

Al usarlo, el dueño de la app pidió dos cambios. La decisión de fondo no cambia
—la cifra se sigue partiendo en lo que ya tiene destino y lo libre—, cambia cómo
se nombra y cuánto detalle muestra:

- **El bloque se llama "Comprometido"**, no "Ya tiene dueño".
- **Cada tarjeta va con su alias y su día límite**, como un recurrente, en vez
  del renglón consolidado "Tarjetas". Textual: *"quiero que me marque lo que voy
  a pagar de las tarjetas"* — y eso es una pregunta por tarjeta, no un total
  anónimo. Con esto, el detalle por tarjeta aparece también en "Esta quincena",
  que se conservó por decisión previa.
- **Lo acumulado después del corte se muestra aparte y no se suma.** Es la misma
  cifra que el detalle de tarjeta llama "Después del corte": esa factura todavía
  no cierra, se paga el mes que entra y va a crecer mientras se use la tarjeta.
  Sumarla a lo comprometido de este mes sería cobrarla dos veces.

## Consecuencias

- `DashboardModel` necesita dos stores más (`RecurringItemStore`,
  `CardPaymentStore`). Entran con valor por omisión `nil` para no romper los
  call sites que ya existen; sin ellos, no hay compromisos y la pantalla se
  comporta exactamente como antes de este ADR.
- Quien no tenga recurrentes ni tarjetas de crédito ve la pantalla de siempre:
  el bloque solo aparece cuando hay algo que desglosar.
- La cifra grande y la libre pueden separarse mucho a principio de mes, que es
  cuando más compromisos faltan. Es el dato correcto, aunque incomode.
