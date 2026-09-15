# ADR-0045: "Te queda" en Hoy es del mes calendario, no el disponible proyectado

- **Estado:** Aceptada
- **Fecha:** 2026-09-15
- **Relacionada:** ADR-0039 (el disponible se ancla al sueldo)

## Contexto

El rediseño abre la app en Hoy con una sola pregunta: "¿cuánto me queda y cuánto
puedo gastar hoy?". La cifra héroe dice **"Te queda"**, con "día 15 de 30" al lado y
"Te toca $170 al día para llegar al 30".

Ya existe otra cifra parecida: `AvailableProjection` (ADR-0039), que va del último
sueldo al siguiente y descuenta recurrentes y pagos de tarjeta pendientes. Es la
respuesta a "¿cuánto me queda de esta quincena?" en el Análisis.

Usar la proyección en Hoy obligaría a cambiar el copy aprobado (el periodo ya no
sería "de 30"), y mezclaría compromisos futuros en la cifra que se lee en tres
segundos.

## Decisión

"Te queda" es **ingreso del mes − gasto del mes, por moneda**, con los totales que
ya calcula `PeriodStatistics` (`DashboardModel.monthTotals`). La barra es gasto sobre
ingreso. El ritmo diario es ese restante entre los días que faltan del mes,
contando hoy; si es negativo, Hoy dice "Ya te pasaste por $X este mes." sin tono de
reproche. Nunca se mezclan monedas: con más de una, la sección es un carrusel.

`AvailableProjection` no cambia y sigue siendo la tool `disponibleProyectado` del
Análisis.

## Consecuencias

- Hoy y el Análisis pueden dar dos cifras distintas. Son dos preguntas distintas
  (lo que queda del mes contra lo que queda hasta el próximo sueldo con los
  compromisos descontados); cada una se nombra por su periodo.
- Quien cobra a mitad de mes ve el sueldo sumado desde el día en que lo registra;
  antes de eso, "Te queda" puede ser bajo o negativo. Es el mismo criterio de
  ADR-0008: solo cuenta lo registrado.
