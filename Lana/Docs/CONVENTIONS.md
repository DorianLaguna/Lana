# Convenciones

## Nombres

- Tipos: `UpperCamelCase`. Protocolos con `-ing` o `-able` (`ExpenseParsing`),
  no con prefijo `I` ni sufijo `Protocol`.
- Implementaciones: nombran su tecnología (`SwiftDataExpenseStore`,
  `FoundationModelsParser`, `InMemoryExpenseStore`).
- Booleanos: `isUnlocked`, `hasBudget`, `needsReview`.
- Todo el código en inglés. La UI y la documentación de producto, en español.
  No mezcles idiomas dentro de un identificador.

## Dinero

`Money` es un struct sobre `Decimal` con la moneda dentro. Nunca `Double`,
nunca `Float`, nunca un `Int` de centavos suelto por ahí.

```swift
// Mal
let total: Double = 300.10 + 120.20

// Bien
let total = Money(amount: 300.10, currency: .mxn) + Money(amount: 120.20, currency: .mxn)
```

Sumar `Money` de monedas distintas es un error en tiempo de compilación o un
`throw`, nunca una conversión silenciosa.

## Errores

Un enum de error por módulo, conformando `LocalizedError`. Nada de `NSError`
genérico ni de `fatalError` fuera de invariantes de programación reales.

```swift
public enum ParsingError: LocalizedError {
    case modelUnavailable(reason: UnavailabilityReason)
    case noAmountFound
    case ambiguousInput(candidates: [String])
}
```

El error tiene que poder mostrarse al usuario en español y con una acción clara.
`case unknown` es una señal de que no entendiste el caso.

## Opcionales

`!` está prohibido salvo en `@IBOutlet` (que no usamos) y en tests. Usa `guard let`
con un `throw` o un valor por defecto explícito.

## Async

- `async/await` en todo. Nada de completion handlers ni Combine.
- Nada de `Task { }` disparado y olvidado dentro de vistas. Si necesitas un task
  ligado al ciclo de vida, usa `.task { }`.
- Los modelos de vista son `@MainActor @Observable`.

## Vistas

- Una vista por archivo si pasa de ~60 líneas.
- Nada de lógica de negocio en `body`. Ni cálculos, ni formateo complejo.
- Todo color, espaciado y tipografía sale de `LanaDesign`. Nada de `.padding(17)`
  ni `Color(red:green:blue:)` sueltos en features.
- Toda vista pública trae un `#Preview` que usa `AppDependencies.preview()`.

## Tests

Swift Testing, no XCTest.

```swift
@Suite("Parseo de montos")
struct AmountValidatorTests {
    @Test("Extrae monto con separador decimal", arguments: [
        ("gasté 300.50 en súper", Decimal(300.50)),
        ("300,50 de súper", Decimal(300.50)),
    ])
    func extraeMonto(input: String, esperado: Decimal) throws {
        let resultado = try AmountValidator().extract(from: input)
        #expect(resultado == esperado)
    }
}
```

- Nombres de test que describen el comportamiento, no el método.
- Un `#expect` por concepto. Si necesitas cinco, probablemente son cinco tests.
- Nada de `sleep`. Usa `await` de verdad o expectativas con timeout.
- Los tests del parser corren contra el golden set y reportan accuracy; no son
  pass/fail individuales.

## Comentarios

- `///` en todo lo `public`. Explica el *por qué*, no el *qué*.
- `// MARK:` para separar secciones en archivos grandes.
- Un comentario que repite el nombre de la función es ruido. Bórralo.
- `// TODO:` lleva contexto y no vive más de un PR. Si va a durar, es un issue.

## Commits

Conventional Commits.

```
feat(parsing): agrega validador de montos con fallback a regex
fix(persistence): corrige round-trip de fechas en zona horaria no-UTC
docs(adr): ADR-0003 sobre estrategia de sync
refactor(core): extrae Money a su propio archivo
test(parsing): amplía golden set a 80 casos
```

Un commit hace una cosa. Si el mensaje necesita "y", son dos commits.

## Antes de cada commit

```bash
swiftformat . && swiftlint --strict && xcodebuild -scheme Lana test
```

Si CI lo va a rechazar, mejor enterarte en tu máquina.

## Eventos y saldos

Los saldos nunca se guardan. Se derivan del ledger (ADR-0005).

```swift
// Mal
sharedList.balance -= amount

// Bien
try ledger.append(.expenseAdded(id: .init(), payer: me, amount: amount, split: .equal))
let balance = ledger.balance(for: me)   // se recalcula
```

Editar es emitir `ExpenseCorrected`. Borrar es emitir `ExpenseVoided`. Nada muta
en su lugar. El caché de saldos vive en memoria, jamás en disco.

## Multi-moneda

Guarda siempre monto original, moneda original y la tasa del día. Nunca conviertas
al guardar. En deuda compartida, la deuda se fija en la moneda del gasto — la
conversión es solo presentación.

## Reglas de UI

Ningún color, espaciado o tamaño literal en una vista. Todo sale de `LanaDesign`.
Lee `.claude/skills/theming/SKILL.md`.

Los montos siempre con `.monospacedDigit()` y alineados a la derecha.

Toda vista pública lleva `#Preview` que itera los seis temas.

Guardar nunca se bloquea: lo ambiguo entra con `needsReview`.

El color nunca es el único portador de información.

## Tarjetas y proyección

Nunca persistas número completo de tarjeta, CVV ni fecha de vencimiento. Solo
alias y últimos cuatro.

Los dos saldos de una tarjeta (actual y al corte) son distintos y se calculan
distinto. No los uses indistintamente.

La deuda con bancos y la deuda con personas viven en ledgers separados.

```swift
// Mal — mezcla dos ledgers
let total = cardDebt + personDebt

// Bien — se muestran por separado
CardBalanceView(debt: ledger.cardDebt(for: card))
PersonBalanceView(debt: ledger.personBalance(with: participant))
```

En `Projection`, solo entran compromisos con fecha. Las cuentas por cobrar se
exponen en una propiedad aparte, nunca dentro del disponible.

## Split proporcional

`SplitRule.proportional` guarda los shares concretos, no una referencia a los
ingresos. La UI muestra la proporción usada en cada gasto, no la actual de la lista.
