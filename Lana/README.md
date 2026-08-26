# Lana

Tracker de gastos para iOS. Escribes "300 de súper y 120 en uber" y quedan
registrados dos gastos categorizados. Todo el procesamiento ocurre en el device.

- **Sin backend.** Los datos viven en el iCloud privado del usuario.
- **Sin suscripción.** Pago único.
- **Sin llamadas de red para el parseo.** Modelo del sistema vía `FoundationModels`.

## Requisitos

- Xcode 26+
- iOS 26+ con Apple Intelligence habilitado
- Swift 6, strict concurrency

## Por dónde empezar

| Archivo | Para qué |
|---|---|
| `PLAN.md` | Plan por fases y alcance de v1.0 |
| `CLAUDE.md` | Contexto y restricciones para Claude Code |
| `Docs/ARCHITECTURE.md` | Módulos y reglas de dependencia |
| `Docs/DATA-FLOW.md` | Cómo viaja un gasto de la captura al saldo |
| `Docs/CONVENTIONS.md` | Estilo de código |
| `Docs/adr/` | Por qué las cosas son como son |

## Setup

```bash
git clone <repo> && cd lana
brew install swiftlint swiftformat
open Lana.xcodeproj
```

El simulador tiene que ser un modelo con Apple Intelligence (iPhone 16 Pro o
superior), o el flujo de captura no arranca.

## Antes de commitear

```bash
swiftformat . && swiftlint --strict && xcodebuild -scheme Lana test
```
