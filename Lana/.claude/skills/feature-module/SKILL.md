---
name: feature-module
description: Crear un módulo de feature nuevo en Lana con la estructura, dependencias y tests correctos. Usa esta skill siempre que se vaya a agregar una pantalla o feature nueva al proyecto, cuando el usuario mencione crear un módulo o paquete, o cuando una feature existente esté creciendo y haya que partirla.
---

# Crear un módulo de feature

Las features en Lana son Swift Packages locales aislados. Aislados de verdad: no
se conocen entre sí (ver `Docs/ARCHITECTURE.md`).

## Estructura

```
Packages/LanaFeatures/<Nombre>Feature/
├── Package.swift
├── Sources/<Nombre>Feature/
│   ├── <Nombre>View.swift        # SwiftUI, sin lógica
│   ├── <Nombre>Model.swift       # @MainActor @Observable, toda la lógica
│   └── Components/               # subvistas privadas
└── Tests/<Nombre>FeatureTests/
    └── <Nombre>ModelTests.swift
```

## Dependencias permitidas

Solo `LanaCore` y `LanaDesign`. Nada más.

Si necesitas parsear o persistir, lo haces a través de los protocolos de
`LanaCore` que se inyectan desde afuera. Importar `LanaParsing` o
`LanaPersistence` desde una feature rompe la arquitectura y hace que el módulo
deje de ser testeable sin simulador.

Si necesitas algo de otra feature, ese algo pertenece a `LanaCore`. Muévelo.

## El modelo

```swift
@MainActor
@Observable
public final class EntryModel {
    private let parser: any ExpenseParsing
    private let store: any ExpenseStore

    public private(set) var state: State = .idle

    public init(parser: any ExpenseParsing, store: any ExpenseStore) {
        self.parser = parser
        self.store = store
    }

    public func parse(_ text: String) async { ... }
}
```

Dependencias por protocolo en el init. Nunca instancies una implementación
concreta adentro — eso es lo que hace imposible testear.

Modela el estado como un enum con casos explícitos (`idle`, `parsing`, `parsed`,
`failed`), no como tres booleanos sueltos. Los booleanos permiten estados
imposibles.

## La vista

`body` no hace `async`, no calcula, no decide. Llama al modelo y renderiza su
estado. Todo color, espaciado y tipografía sale de `LanaDesign`.

Toda vista pública lleva `#Preview` con `AppDependencies.preview()`.

## Pasos

1. Crea el `Package.swift` copiando el de una feature existente y ajustando nombres.
2. Agrégalo como dependencia del target `App`.
3. Escribe el modelo primero, con sus tests. La vista después.
4. Verifica que `swift test --package-path` de ese paquete corra sin simulador.
   Si necesita simulador, algo se coló que no debía.
5. Conéctalo en `AppDependencies` y en la navegación.

## Antes de dar por terminado

- [ ] El paquete compila aislado
- [ ] Los tests del modelo corren sin simulador
- [ ] No hay imports de otras features ni de implementaciones concretas
- [ ] Todo lo `public` tiene `///`
- [ ] Hay `#Preview` funcionando
