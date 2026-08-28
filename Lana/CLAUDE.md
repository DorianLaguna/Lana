# Lana — contexto del proyecto

App de gastos para iOS. Parseo de lenguaje natural 100% on-device con
`FoundationModels`. Gastos compartidos con saldos vía CloudKit. Sin backend.

**Para qué existe:** que su dueño se haga el hábito de registrar gastos. Abandonó
otros sistemas porque capturar y categorizar se sentía tedioso. Cuando dudes entre
dos opciones, gana la que quita fricción de la captura.

## Antes de tocar código

- `PLAN.md` — fases y alcance. Ubica en cuál estás.
- `Docs/ARCHITECTURE.md` — módulos y reglas de dependencia.
- `Docs/DATA-FLOW.md` — el recorrido completo de un gasto, de la captura al saldo.
- `Docs/CONVENTIONS.md` — estilo. No son sugerencias.
- `Docs/adr/` — el porqué. Si vas a contradecir un ADR, para y pregunta.
- Si el cambio toca estructura o dependencias, el ADR va en el mismo cambio.

## Comandos

```bash
xcodebuild -scheme Lana -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -scheme Lana -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
swift test --package-path Packages/LanaCore
swiftlint --strict && swiftformat .
swift run parser-eval Tests/Fixtures/golden-set.json
```

El simulador debe tener Apple Intelligence, o la suite del parser se salta.
CloudKit sharing **no se puede probar en simulador** — requiere dos devices
físicos con cuentas de iCloud distintas.

## Restricciones no negociables

**Dinero nunca es `Double`.** Usa `Money` (`Decimal` + moneda). Un error de
redondeo es un bug que el usuario ve en su saldo.

**Los saldos nunca se persisten.** Se derivan plegando eventos (ADR-0005). Si
encuentras código que guarda un saldo, es un bug, no una optimización.

**Nunca guardes el número completo de una tarjeta, CVV ni fecha de vencimiento.**
Alias y últimos cuatro dígitos alcanzan para todo lo que hace la app.

**La deuda con tarjetas y la deuda con personas son ledgers separados.** Un gasto
compartido pagado con tarjeta genera las dos. Nunca las sumes ni las mezcles en la
misma vista.

**La proyección solo cuenta lo que tiene fecha** (ADR-0008). Las cuentas por cobrar
van en sección aparte, jamás sumadas al disponible.

**La proporción de un split se congela en el evento** (ADR-0007). Cambiar el ratio
de la lista aplica hacia adelante; nunca recalcula el historial.

**Todo lo capturado automáticamente entra con `needsReview`** — Apple Pay (ADR-0009)
y tickets escaneados (ADR-0010). Nunca como dato confirmado.

**Un ticket es solo otra forma de producir texto.** OCR → el parser que ya existe.
Si escribes un segundo parser para recibos, algo está mal.

**Apple Pay específicamente:** El trigger
de Shortcuts se pasa de tiempo y dispara en transacciones rechazadas.

**Los eventos son inmutables.** Editar emite una corrección; borrar emite una
anulación. Nada se muta en su lugar.

**El regex gana sobre el modelo en el monto.** `AmountValidator` corre siempre
sobre el texto crudo. Si discrepan, gana el regex y la transacción se marca
`needsReview`.

**Guardar nunca se bloquea.** Si el parseo es ambiguo, se guarda con
`needsReview` y se resuelve después. Un gasto incompleto vale más que uno que no
se registró.

**`LanaCore` solo importa `Foundation`.** Ni SwiftUI, ni Core Data, ni
FoundationModels.

**Las features no se importan entre sí** ni importan implementaciones concretas.

**Ningún color ni espaciado literal en vistas.** Todo sale de `LanaDesign`. Lee
`.claude/skills/theming/SKILL.md` antes de escribir UI.

**Siempre se checa `availability` antes de crear una `LanguageModelSession`.**

**En consultas de lenguaje natural, el modelo no calcula.** Se le dan tools
deterministas y él narra el resultado.

## Estilo

- Swift 6, strict concurrency.
- Swift Testing (`@Test`, `#expect`), no XCTest salvo UI tests.
- `///` en todo lo `public`.
- Conventional Commits. Un commit hace una cosa.
- Sin dependencias externas nuevas sin ADR.

## Tono del producto

Lana no regaña. Un presupuesto excedido es un dato con su acción al lado, no un
reproche. El usuario ya abandonó otras apps; lo último que necesita es sentirse
mal por gastar. Esto aplica al copy y al color.

## Fuera de v1.0

Escaneo de tickets, exportación, presupuestos compartidos. Si una tarea
empieza a rozar esto, para y pregunta.

Captura por voz **ya está dentro de v1.0** (decisión 2026-08-26, ver
ADR-0015) — es on-device vía el Speech framework de Apple, con parada
manual (el usuario toca el micrófono de nuevo para terminar). Es "otra
forma de producir texto" que alimenta el mismo parser — no es un segundo
parser ni un segundo camino de captura.

Un widget de Home Screen con un App Intent mínimo **ya está dentro de
v1.0** (decisión 2026-08-27, ver ADR-0018) — un solo widget que abre la
app directo en modo escucha, vía un deep link (`lana://capture`), para
capturar con el menor número de toques posible. No es un widget
informativo (no muestra saldos ni gastos) ni un App Intent de Siri
completo — solo el atajo de abrir-y-escuchar.
