# ADR-0061: Ligar un movimiento a su recurrente se pregunta en "Por revisar"

- **Estado:** Aceptada
- **Fecha:** 2026-10-01
- **Enmienda:** ADR-0042 (el recurrente de un movimiento se fijaba al crearlo)
- **Relacionada:** ADR-0005 (los eventos conmutan), ADR-0060 ("Ya cuentan en
  octubre" separa compras de recurrentes)

## Contexto

Hoy separa lo que se compró con tarjeta de lo que salió de un recurrente
(ADR-0060). Para eso mira `Expense.recurringItemID`, que solo traen los
movimientos registrados desde un recurrente después de ADR-0042. Lo registrado
antes, o lo dictado a mano ("netflix 139"), no lo trae: el dueño vio una
tarjeta con 16 compras y ningún recurrente.

Hasta este ADR, ninguna corrección podía poner `recurringItemID`: se fijaba en
`ExpenseAdded`.

Alternativas consideradas:

- **Adivinarlo al leer** (mismo nombre, o contenido con el mismo monto). Se
  probó: funciona, pero falla en los dos sentidos —un recurrente registrado con
  otro nombre no aparece, y una compra que se llama parecido sí— y nadie lo
  confirma. El dueño lo encontró raro.
- **Ligarlo a mano en la edición** ("Es de un recurrente: Netflix ▾"). Es lo
  más confiable, pero hay que encontrar cada movimiento. Descartado por el
  dueño a favor de que Lana proponga.
- **Guardar el "no es" en el recurrente.** `RecurringItem` vive en Core Data
  con un atributo por campo: un campo nuevo es un cambio de modelo y de
  esquema de CloudKit. El rechazo es un hecho sobre el movimiento; va en su
  evento.

## Decisión

- **`ExpenseCorrected` puede ligar y rechazar.** Trae `recurringItemID`
  (`nil` conserva el que hubiera; ninguna corrección lo quita) y
  `declinedRecurringItemIDs`, que **se suman** a los de correcciones
  anteriores en vez de reemplazarlos, para que el orden de plegado no importe
  (ADR-0005). Los dos son opcionales: las correcciones guardadas decodifican
  igual, y van en el JSON del evento, sin cambiar el modelo de Core Data.
- **Lana propone, el usuario confirma** (`RecurringLinking.suggestions`). Se
  propone un movimiento sin vínculo, ya revisado, del mismo tipo y moneda que
  un recurrente, que se llama igual (sin importar mayúsculas ni acentos) o
  cuyo nombre contiene al otro con el mismo monto. Uno por recurrente y mes;
  nunca un recurrente que ya tiene su movimiento ese mes, ni uno que el usuario
  ya rechazó para ese movimiento.
- **La pregunta vive en "Por revisar"**, debajo de lo dudoso: "netflix · $139
  · 26 sept 2026 · ¿Es tu recurrente Netflix?" con "No es" y "Sí, es Netflix".
  Cada respuesta se guarda al tocarla. El contador de Hoy las incluye.
- **Solo cubre lo que Hoy y Mes tienen cargado** (del mes anterior a hoy): es
  lo que mueve sus cifras. El historial viejo no se barre.
- **Hoy deja de adivinar.** "Recurrentes" en "Ya cuentan en octubre" es solo
  lo ligado; lo demás es compra hasta que se confirme.

## Consecuencias

- Ligar un movimiento cuenta como el registro de ese mes (ADR-0042): un
  "netflix" dictado y confirmado deja de aparecer como pendiente en
  Comprometido, y el registro automático no lo duplica.
- Un ingreso dictado ("sueldo") también se puede ligar, y deja de esperarse en
  "Te queda" (ADR-0060).
- La primera vez puede haber varias preguntas juntas: una por recurrente en
  cada uno de los dos meses cargados.
- Un movimiento ligado por error no se puede desligar desde la app. Se borra y
  se recaptura.

## Qué haría reconsiderar esto

- Que las preguntas se acumulen sin contestar: convendría ligar solo lo de
  nombre exacto y preguntar únicamente lo dudoso.
- Que haga falta desligar seguido: `ExpenseCorrected` necesitaría una bandera
  explícita, como `clearsSharedContext` (ADR-0027).
