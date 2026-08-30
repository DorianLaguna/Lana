# ADR-0021: Identidad local de "quién soy yo" en una lista compartida

- **Estado:** Superseded por ADR-0022 (el mecanismo de almacenamiento — de
  `UserDefaults` local a una entidad de Core Data sincronizada por iCloud
  privado — el resto de las decisiones de este ADR sigue vigente)
- **Fecha:** 2026-08-28

## Contexto

Con G3 (ADR-0020) ya sincronizando listas compartidas de verdad, apareció un
bug real en pruebas: un gasto de $1200 pagado por el usuario, dividido 50/50
con su pareja, se veía en su Dashboard **personal** con el monto completo —
"como si yo hubiera pagado todo". La otra mitad ya vive separada como cuenta
por cobrar dentro de la lista compartida; mostrar el total en el Dashboard
personal la cuenta dos veces.

La causa raíz: Lana no tiene ningún concepto de "cuál de los participantes de
una lista soy yo". `Participant` es solo texto libre (`displayName`) — sin
identidad real de CKShare todavía (ADR-0017 la deja pendiente a propósito), no
hay forma de saber si "Alice" en el roster es este dispositivo o el de la
pareja.

## Decisión

**La identidad vive local, en `UserDefaults`, nunca en `SharedList`.**
`SharedListViewerIdentity` (`LanaCore`) son funciones puras sobre un
`UserDefaults` inyectado — mismo patrón que `SettingsModel` con el tema
elegido — guardando `ParticipantID` por `SharedListID`.

*Alternativa descartada:* un campo `viewerParticipantID` en `SharedList`
mismo. Descartada de inmediato: `SharedList` se sincroniza por `CKShare`, y el
mismo roster tiene un significado **distinto por dispositivo** — en el mío
"yo" soy Alice, en el de mi pareja "yo" es Bob. Ponerlo ahí sincronizaría la
respuesta equivocada al otro dispositivo.

**Dos flujos para marcarla**, elegidos explícitamente por el usuario:

1. Al **crear** una lista (`CreateSharedListModel`): un `Picker` "¿Cuál de
   estos eres tú?" sobre los nombres que se están escribiendo, default el
   primero (casi siempre te escribes a ti mismo primero). El índice elegido
   se remapea contra el roster ya filtrado (sin las casillas vacías) antes de
   guardar.
2. Para listas que **ya existían** antes de este cambio, o llegaron por
   invitación real de CKShare (el roster lo escribió alguien más):
   `SharedListDetailModel.needsViewerPrompt` se calcula en el propio `init`
   si no hay identidad guardada, y la vista muestra un sheet ("¿Quién eres
   aquí?") la primera vez que se abre esa lista. Dismissable sin elegir — si
   pasa, se vuelve a preguntar la próxima vez (el modelo se reconstruye en
   cada navegación, así que se recalcula solo).

El cálculo de "mi parte" es siempre **derivado al mostrar**, nunca escrito de
vuelta al evento — así, gastos ya guardados antes de marcar la identidad se
corrigen solos en el Dashboard en cuanto se marca, sin tocar nada persistido.

**Cómo se calcula:** `Expense.personalAmount(userDefaults:)` (extensión en
`LanaCore`). Sin `sharedListID`, o sin identidad marcada todavía, regresa el
monto completo — respaldo seguro, nunca `0` ni un crash. Con identidad, usa
`split.portions(of: amount)[viewerID]` — el split **congelado en el propio
evento** (ADR-0007), nunca el vigente de la lista.

**Caso especial encontrado al implementar:** `SplitRule.payerOnly` siempre
regresa `portions == [:]` (vacío, a propósito, documentado desde antes de este
cambio). Con la lógica genérica ("si mi id no está en `portions`, usar el
monto completo como respaldo"), esto le daba el monto **completo a cualquier
participante**, no solo a quien pagó — incorrecto para quien no pagó, cuyo
costo real ahí es cero. Se agregó el caso explícito: `split == .payerOnly` →
monto completo solo si `viewerID == payer`, `Money.zero` para cualquier otro.
Probado con los dos casos.

**Dónde se usa:** `DashboardModel`/`CategoryDetailModel`/
`PaymentMethodDetailModel` (los totales/desgloses personales del Dashboard) y
`DaySectionListView` (la fila individual — `TransactionRow`, `LanaDesign`,
gana un parámetro `isShared: Bool = false` para el ícono `person.2`, sin
romper ningún call site existente).

**Dónde deliberadamente NO se usa:** `CardLedger`/Tarjetas y
`PaymentMethodDetailModel.cardTotals` — el banco cobra el monto completo a la
tarjeta sin importar el split, es deuda real, no gasto personal (mismo
criterio ya establecido para Cards). Tampoco `SharedListDetailView` — ahí sí
es correcto ver el total real del gasto y quién pagó, eso es justo lo que esa
pantalla existe para mostrar.

## Consecuencias

**Bueno:**

- El bug reportado ("como si yo hubiera pagado todo") queda resuelto de raíz,
  no con un parche visual — `personalAmount` es la fuente de verdad para
  cualquier vista personal futura que sume gastos.
- Nada se sincroniza de más: la identidad es puramente local, consistente con
  que el mismo roster signifique algo distinto en cada dispositivo.
- Gastos ya guardados se corrigen solos al marcar identidad — no hace falta
  ninguna migración ni recalcular nada persistido.

**Malo / a vigilar:**

- Mientras no se marque identidad (usuario nuevo, o dismissió el prompt), el
  Dashboard sigue mostrando el monto completo de cualquier gasto compartido —
  el bug original sigue latente hasta que el usuario marca quién es. El
  prompt reaparece cada vez que se reabre la lista, pero nada fuerza a
  elegir.
- `personalAmount` no distingue entre "todavía no hay identidad marcada" y
  "el participante fue removido del roster" — ambos casos caen al mismo
  respaldo (monto completo). Si esto genera confusión real en uso, vale la
  pena separar esos dos casos con una señal explícita.
- Encontramos que `swift test --package-path` (SPM directo, lo que corre CI
  por paquete) truena con "the compiler is unable to type-check this
  expression in reasonable time" si se mete demasiada lógica inline dentro de
  un `TransactionRow(...)` ya anidado en `ForEach`/`Button` —
  `xcodebuild`/whole-module-optimization no lo detecta. Se resolvió
  extrayendo la construcción a un método privado con variables locales por
  argumento (`DaySectionListView.row(for:)`). Vale la pena recordar este
  patrón si aparece de nuevo: un build de Xcode verde no garantiza que
  `swift test` por paquete (lo que corre CI) también lo esté.
