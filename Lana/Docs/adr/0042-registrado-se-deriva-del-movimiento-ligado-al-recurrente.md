# ADR-0042: Que un recurrente esté registrado se deriva de su movimiento, no de una marca

- **Estado:** Aceptada
- **Fecha:** 2026-09-15

## Contexto

Con un sueldo recurrente del día 15, pasó esto:

1. Antes del 15 el usuario tocó la palomita del recurrente. Parecía un "¿ya pasó?", pero en
   realidad registraba el ingreso con fecha de ese día.
2. Al registrarse, la palomita desaparecía. Ya no había forma de ver si faltaba o si ya estaba.
3. Vio un ingreso que todavía no le llegaba y lo borró.
4. Llegó el 15 y la app no lo registró sola.

La causa: el estado "ya registrado este mes" era una marca guardada en el recurrente
(`lastRegisteredMonth`), sin relación con el movimiento. Borrar el movimiento emitía su
anulación, pero la marca se quedaba. El registro automático no lo volvía a registrar, y la
proyección del disponible dejaba fuera un sueldo que no existía.

Alternativas consideradas:

- **Limpiar la marca al borrar el movimiento.** Obliga a que cada lugar donde se borra un
  gasto (Dashboard, detalle de tarjeta, listas compartidas) actualice también otro store.
  Además hay dos stores que se sincronizan por separado con CloudKit y pueden quedar
  inconsistentes. Un solo lugar olvidado reproduce el bug.
- **Emparejar por nombre y tipo** (hay un ingreso "Sueldo" en el mes). No necesita cambiar
  el modelo, pero falla justo con este usuario: tiene dos sueldos que se llaman igual, el
  del 15 y el del 31, y un solo movimiento marcaría ambos.
- **Ligar el movimiento al recurrente y derivar el estado.** Es lo mismo que ya se hace con
  los saldos (ADR-0005). Requiere un campo nuevo en los eventos.

## Decisión

**Cada movimiento registrado desde un recurrente lleva `recurringItemID`** (en `ExpenseAdded`,
`IncomeAdded` y `Expense`). Un recurrente está registrado en un mes si existe un movimiento
vigente ligado a él en ese mes (`RecurringItem.registration(in:forMonthOf:calendar:)`). Al
borrar el movimiento, la anulación lo saca del ledger y el recurrente vuelve a quedar
pendiente, sin importar desde dónde se borró.

**El registro automático corre una vez por mes por recurrente** (`lastAutoRegisteredMonth`).
Esa pasada marca el mes aunque el recurrente ya estuviera registrado a mano. Si después se
borra el movimiento, el recurrente queda pendiente pero Lana no lo vuelve a postear sola. Un
sueldo que se retrasó y se borró a propósito no debe reaparecer cada vez que se abre la app.

**`lastRegisteredMonth` ya no se escribe.** Se sigue leyendo como `.legacy` para no volver a
registrar ni a contar lo que se registró antes de este cambio.

En la interfaz, la palomita muestra el estado: llena significa registrado ("Registrado el 12
sep") y vacía significa pendiente ("Pendiente · día 15"). Si se registra antes de que venza,
se pide confirmación. El Dashboard también corre el registro automático al volver a primer
plano.

## Consecuencias

- Borrar un movimiento reabre su recurrente desde cualquier pantalla, sin coordinar stores.
- La proyección del disponible ya no omite un recurrente cuyo movimiento se borró.
- `PayPeriod.commitments` ahora necesita los movimientos de los meses completos que toca el
  periodo, no solo los del periodo: un sueldo adelantado el 10 cubre la ocurrencia del 15.
  Eso es una lectura más al store en `disponibleProyectado`.
- **Lo registrado antes de este cambio no tiene liga.** Si en ese mismo mes se borra uno de
  esos movimientos, la marca heredada lo sigue mostrando como registrado. Esto solo afecta el
  mes en que se instala la actualización.
- `CDRecurringItem` gana un atributo opcional (`lastAutoRegisteredMonth`). La migración
  ligera lo cubre, pero el esquema de CloudKit hay que desplegarlo a producción antes de
  publicar.
- Un movimiento capturado a mano ("sueldo 15000") no cuenta como registro del recurrente,
  aunque sea lo mismo. Si el usuario suele hacer eso, el automático lo duplicaría.

## Qué haría reconsiderar esto

- Si se vuelve común capturar a mano lo que ya es recurrente, convendría que la captura
  sugiera ligarlo al recurrente, en lugar de adivinar por nombre.
- Si se permite registrar varias ocurrencias de un recurrente en el mismo mes (por ejemplo,
  uno semanal), "registrado en el mes" deja de alcanzar y habría que ligar a la ocurrencia.
