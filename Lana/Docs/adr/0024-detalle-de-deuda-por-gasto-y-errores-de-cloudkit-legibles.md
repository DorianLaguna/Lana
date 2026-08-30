# ADR-0024: Detalle de deuda gasto por gasto, y errores de CloudKit traducidos a mensajes legibles

- **Estado:** Aceptada
- **Fecha:** 2026-08-28

## Contexto

Probando ADR-0023 en dos iPhones reales, el usuario reportó tres cosas
sueltas:

1. Al invitar a la lista "Us" (con historial real de varios meses),
   compartir falló con un `CKError` crudo mostrado tal cual en pantalla —
   un bloque de texto con UUIDs de registro y errores parciales anidados,
   totalmente ilegible. El código raíz (`.quotaExceeded` envuelto en
   `.partialFailure`) venía de que compartir una `CDSharedList` mueve, en
   una sola operación, **todos** sus `CDEvent` relacionados a la zona de
   registro nueva (documentado en `CoreDataSharedListSharing.swift` desde
   ADR-0020) — con suficiente historial, esa operación puede rebasar la
   cuota de CloudKit. En el entorno de Desarrollo (el que usa cualquier
   build corrido desde Xcode) esa cuota es, a propósito, mucho más baja que
   en Producción — para no gastar cuota real durante pruebas — así que este
   error es mucho más probable ahora que una vez publicada la app
   (TestFlight/App Store usan el entorno de Producción).
2. "Que si le presiono a cuánto debe una persona a la otra... deben salir
   como el listado de por qué, cuánto de cada gasto, cómo se dividió." La
   fila de deuda en `BalancesView` mostraba solo la cifra ya simplificada
   (`Debt`, producto de `PersonLedger.simplifiedDebts`), sin forma de ver
   qué gastos la componen.
3. "Que pasa si no tiene espacio en iCloud? Nunca se guarda en la nube? Me
   gustaría decirle al usuario que trate de guardarlo en la nube, que si
   no, su información podría perderse." El indicador de sync (ADR-0020,
   `SettingsView`) ya existía pero su texto para `.failed` no explicaba que
   los datos siguen a salvo localmente (Core Data escribe a SQLite primero,
   siempre — CloudKit es un respaldo asíncrono, nunca la única copia), ni
   sugería una acción concreta.

## Decisión

**1. `CKError` nunca llega crudo a una vista.**

`PersistenceError` (ya existente, `LanaPersistence`) gana dos casos:
`.cloudKitQuotaExceeded(retryAfterSeconds:)` y `.cloudKitSharingFailed`.
`CoreDataSharedListSharing.shareURL(for:)` traduce cualquier `CKError` de
las dos llamadas de CloudKit (`share(_:to:)`, `persistUpdatedShare`) a uno
de estos casos — buscando `.quotaExceeded` tanto en el error de primer
nivel como anidado dentro de un `.partialFailure`, para extraer
`retryAfterSeconds` si CloudKit lo dio. Como `PersistenceError` ya es
`LocalizedError` y `SharedListDetailModel.prepareShare()` ya usaba
`error.localizedDescription`, ningún código de `SharedFeature` cambió —
el mensaje amigable sale gratis en cuanto `LanaPersistence` deja de
regalar el `CKError` original.

Este cambio no resuelve la causa raíz (mover un objeto-grafo grande en una
sola operación de share) — solo evita que el usuario vea un error
ilegible. Si esto se vuelve frecuente en Producción (no solo en
Desarrollo, donde es casi seguro con listas viejas), la solución real
sería paginar el historial que se mueve al compartir, no solo traducir el
mensaje.

**2. `PersonLedger` gana `contributions(between:and:in:)`.**

Nuevo tipo, `DebtContribution` (`LanaCore/Ledger/Debt.swift`): por cada
gasto que involucra a los dos participantes consultados, guarda concepto,
fecha, monto total, quién pagó, la parte de cada uno de los dos
(`SplitRule.portions(of:)`, ya existente), y `signedEffect` — positivo si
el gasto aumenta lo que `from` le debe a `to` (pagó `to`), negativo si lo
reduce (pagó `from`). Un `.payerOnly` nunca contribuye (su `portions(of:)`
regresa vacío — nadie más debe nada de él, mismo criterio que ya usa
`netBalances`).

**Con exactamente dos participantes en la lista, la suma de
`signedEffect` siempre coincide con el `Debt.amount` ya simplificado** —
es aritméticamente el mismo cálculo, solo expuesto gasto por gasto en vez
de ya sumado. Con 3+ participantes, `simplifiedDebts` puede combinar
deudas transitivas (A le debe a B, B le debe a C se simplifica a A le debe
a C directamente) que no corresponden a ningún gasto directo entre A y C
— `contributions` en ese caso muestra la relación *directa* entre los dos
participantes consultados, ignorando a cualquier tercero, que puede no
sumar idéntico a la cifra ya simplificada. Se documentó explícitamente en
el doc comment del método y no se intentó "arreglar" — forzar que
coincidan exigiría atribuir una simplificación transitiva a gastos
concretos que nunca existieron entre esas dos personas, lo cual sería
inventar información, no mostrarla.

`SharedListDetailModel` guarda el log crudo de la última carga
(`private var events`) para poder llamar `contributions(for debt:)` sin
otro viaje al store. `DebtDetailView` (nuevo, `SharedFeature`) muestra la
cifra total arriba, y abajo la lista de gastos con su fecha, quién pagó,
la parte de cada uno, y un acumulado corriendo que llega exactamente a esa
misma cifra. Se abre tocando la fila de deuda en `BalancesView` (que ganó
un `onSelectDebt` junto al `onSettle` que ya tenía) — el botón "Liquidar"
sigue siendo su propio control, sin disparar los dos a la vez.

**3. El mensaje de sync fallido explica que los datos siguen locales, y
sugiere una acción.**

`SettingsView.syncStatusText` para `.failed` pasó de "No se pudo
sincronizar la última vez" a explicar que el respaldo a iCloud falló pero
los datos siguen en el dispositivo, y a sugerir revisar conexión o espacio
en iCloud. Sigue en tono "dato, no alarma" (Docs/CLAUDE.md): no hay
alarma, cambio de color a `critical`, ni bloqueo de ninguna acción — la
app nunca dejó de guardar localmente aunque el respaldo a la nube falle
(Core Data escribe a SQLite primero siempre; CloudKit es asíncrono y
best-effort encima de eso), y ese hecho es justo lo que la copia ahora
dice explícitamente.

## Consecuencias

**Bueno:**

- Ningún `CKError` crudo debería volver a aparecer en pantalla al
  compartir una lista.
- La pregunta "¿de dónde sale esta deuda?" tiene respuesta dentro de la
  app, sin tener que reconstruir el historial a mano.
- El usuario sabe, sin tener que preguntar, que un fallo de sync no
  implica pérdida de datos — solo que el respaldo a la nube está
  pendiente.

**Malo / a vigilar:**

- El `.quotaExceeded` de Desarrollo seguirá apareciendo mientras se prueba
  localmente con listas de mucho historial — el mensaje ahora es legible,
  pero el usuario todavía tiene que esperar los minutos que indique
  CloudKit. Vale la pena confirmar en TestFlight/Producción si esto deja
  de repetirse (debería, por la cuota mucho más alta), y si no,
  reconsiderar paginar la migración de eventos al compartir.
- `contributions` puede mostrar una suma que no coincide con el `Debt` ya
  simplificado en listas de 3+ participantes — está documentado, pero si
  se vuelve confuso en la práctica, la UI necesitaría dejarlo aún más
  explícito (p. ej. una nota visible cuando ambas cifras difieren, no solo
  en el doc comment del código).
- El indicador de sync sigue viviendo solo en Settings — un fallo de sync
  no se asoma en ningún otro lugar de la app (Dashboard, Compartido). Si
  el usuario sigue sin verlo a tiempo, la siguiente iteración sería
  hacerlo más visible fuera de Settings, no solo mejorar su texto.
