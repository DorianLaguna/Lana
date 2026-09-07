# Implementation Plan: Guía de configuración de Apple Pay

## Overview

La implementación avanza de adentro hacia afuera del grafo de dependencias, siguiendo ARCHITECTURE.md y CONVENTIONS.md:

1. **Contenido estático + protocolo de entorno en `LanaCore`** (Foundation puro): los tipos de datos de la guía y su instancia `.standard`, más `ApplePayEnvironmentProbing` / `InMemoryApplePayEnvironment`. Se prueban primero (propiedades 2, 3, 4, 5) porque no dependen de nada.
2. **`GuiaApplePayModel`** en la nueva `OnboardingFeature` (`@MainActor @Observable`): la máquina de estados de navegación, el resumen de cierre y los estados de error. Se prueban su máquina de estados (propiedad 1), el resumen (propiedad 6) y todos los edge cases de error.
3. **Contenedor `OnboardingModel` y vistas** (`GuiaApplePayView` + subvistas + estados de error).
4. **Ensamblaje en `App`/`ContentView`**: bandera `hasCompletedOnboarding`, `ApplePayEnvironmentProbe` real, handlers inyectados y la fila de reingreso en `SettingsView`.

Cada bloque termina cableado con el anterior; no queda código huérfano. El testing usa **Swift Testing** (no XCTest), prueba **modelo y contenido, nunca la vista**, con seis pruebas por propiedad (mínimo 100 iteraciones cada una) más tests de ejemplo y edge cases. Latencias (R1.2, R6.1, R6.3) y la implementación real de `ApplePayEnvironmentProbing` quedan fuera del testing automatizado (verificación manual en dispositivo).

## Tasks

- [x] 1. Definir contenido estático y protocolo de entorno en LanaCore
  - [x] 1.1 Definir el protocolo de entorno de Apple Pay
    - Crear `Protocols/ApplePayEnvironmentProbing.swift` en `LanaCore` con el protocolo `ApplePayEnvironmentProbing: Sendable` (`isShortcutsAutomationAvailable`, `isRunningInSimulator`)
    - Agregar `InMemoryApplePayEnvironment` (misma carpeta) con inicializador de valores por defecto para previews y tests
    - Mantener `Foundation` puro, sin dependencias de UIKit ni de frameworks de Apple
    - _Requirements: 2.6, 5.2_

  - [x] 1.2 Crear los tipos de datos anidados del contenido
    - Crear `Models/GuiaApplePayContent.swift` en `LanaCore` con `GuiaStep`, `ParameterMapping` (con enum `Parameter { amount, merchant, cardName }`), `MatchingExplanation`, `MatchSignal`, `KnownLimitation` (con enum `Kind` de seis casos) y `DeviceRequirement`
    - Todos `Sendable`, `Equatable`, e `Identifiable` donde el diseño lo indica; sin lógica, solo datos de valor
    - _Requirements: 2.1, 2.3, 3.1, 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 5.1, 5.2_

  - [x] 1.3 Definir el struct `GuiaApplePayContent` y su instancia `.standard`
    - Componer `deviceRequirement`, `shortcutSteps`, `parameterMappings`, `matching` y `limitations`
    - Poblar `.standard` con el contenido real en español: pasos numerados de Atajos (abrir Atajos, crear automatización, seleccionar disparador Wallet, agregar la acción del App Intent, guardar), el título exacto "Agregar transacción de Apple Pay", una automatización por tarjeta, ejecución sin confirmación, mapeo monto/comercio/nombre de tarjeta, señales de emparejamiento (últimos 4 dígitos primero, luego alias/NombreEnWallet), guía de mismatch y de no-match, las seis limitaciones y los mensajes de dispositivo físico y simulador
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 3.1, 3.2, 3.3, 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 5.1, 5.2_

  - [x] 1.4 Escribir prueba por propiedad para la numeración de los pasos de Atajos
    - **Property 2: Los pasos de Atajos están numerados de forma consecutiva y ordenada**
    - **Validates: Requirements 2.1**
    - Swift Testing, mínimo 100 iteraciones; etiqueta `Feature: apple-pay-setup-guide, Property 2`
    - Verificar `ids == [1, 2, ..., n]` sin huecos ni duplicados y cobertura de los pasos mínimos
    - Ubicar en `Tests/LanaCoreTests`

  - [x] 1.5 Escribir prueba por propiedad para la biyección del mapeo de parámetros
    - **Property 3: El mapeo de parámetros es una biyección total sobre los tres parámetros**
    - **Validates: Requirements 2.3**
    - Swift Testing con `arguments:` sobre `ParameterMapping.Parameter.allCases`, mínimo 100 iteraciones; etiqueta `Feature: apple-pay-setup-guide, Property 3`
    - Verificar exactamente un mapeo por parámetro y `intentParameter == walletParameter`

  - [x] 1.6 Escribir prueba por propiedad para el orden de prioridad de señales de emparejamiento
    - **Property 4: Las señales de emparejamiento están ordenadas por prioridad, con últimos-4-dígitos primero**
    - **Validates: Requirements 3.1**
    - Swift Testing, mínimo 100 iteraciones; etiqueta `Feature: apple-pay-setup-guide, Property 4`
    - Verificar `MatchSignal.id` consecutivos desde 0, estrictamente crecientes, e índice 0 == últimos 4 dígitos

  - [x] 1.7 Escribir prueba por propiedad para la cobertura de limitaciones conocidas
    - **Property 5: Cobertura total de las limitaciones conocidas**
    - **Validates: Requirements 4.1, 4.2, 4.3, 4.4, 4.5, 4.6**
    - Swift Testing con `arguments:` sobre `KnownLimitation.Kind.allCases`, mínimo 100 iteraciones; etiqueta `Feature: apple-pay-setup-guide, Property 5`
    - Verificar exactamente una entrada por `kind` con `message` no vacío, sin duplicados

  - [x] 1.8 Escribir tests de ejemplo para la presencia de contenido clave
    - Verificar el título exacto "Agregar transacción de Apple Pay" (R2.2), la instrucción de una automatización por tarjeta (R2.4), la ejecución sin confirmación (R2.5), la guía de `walletMatchHint` (R3.2), la guía de no-match con alias/NombreEnWallet/últimos 4 (R3.3) y que `physicalDeviceMessage` y `simulatorMessage` no estén vacíos (R5.1, R5.2)
    - _Requirements: 2.2, 2.4, 2.5, 3.2, 3.3, 5.1, 5.2_

- [x] 3. Checkpoint — Contenido y protocolo de LanaCore
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 4. Crear la feature OnboardingFeature y el modelo de la guía
  - [-] 4.1 Configurar el paquete `OnboardingFeature`
    - Crear `Packages/LanaFeatures/OnboardingFeature` con `Package.swift` dependiendo solo de `LanaCore` y `LanaDesign` (nunca otra feature)
    - Reflejar la estructura de las features existentes (`Sources/OnboardingFeature`, `Tests/OnboardingFeatureTests`)
    - _Requirements: 1.1_

  - [x] 4.2 Implementar el esqueleto de estado de `GuiaApplePayModel`
    - Crear `Sources/OnboardingFeature/GuiaApplePayModel.swift` como `@MainActor @Observable final class`
    - Definir `Mode { onboarding, standalone }`, `Screen: Int, CaseIterable { requirements, shortcutSteps, matching, limitations, closing }` y `CompletionStep`
    - Definir propiedades observadas: `currentScreen`, `content`, `presentationError`, `summaryUnavailable`, `advanceError`, `isFinished`, `isAutomationAvailable`, `isRunningInSimulator`, más el inicializador que toma `mode`, `content` y `environment`
    - _Requirements: 1.2, 5.3_

  - [x] 4.3 Implementar la navegación de la máquina de estados
    - Implementar `presentFirstScreen()` (fija `.requirements` con contenido válido; fija `presentationError` sin cambiar de pantalla si `content == nil`), `next()`, `back()` y `retryPresentation()` respetando los invariantes: índice en `[0, Screen.allCases.count)`, inicio en `.requirements`, movimientos de exactamente 1, no-op en los extremos, y `next()` en `.closing` no avanza el índice
    - Poblar `isAutomationAvailable` / `isRunningInSimulator` desde el `environment` inyectado
    - _Requirements: 1.2, 2.6, 5.2, 5.3_

  - [x] 4.4 Escribir prueba por propiedad para los invariantes de la máquina de estados
    - **Property 1: Invariantes de la máquina de estados de navegación**
    - **Validates: Requirements 1.2, 5.3, 6.1**
    - Swift Testing con un generador de secuencias aleatorias de acciones `next`/`back`, mínimo 100 secuencias; etiqueta `Feature: apple-pay-setup-guide, Property 1`
    - Verificar índice en rango, inicio en `.requirements`, movimientos ±1 (o sin cambio en extremos) y `requirements.rawValue < shortcutSteps.rawValue`
    - Ubicar en `Tests/OnboardingFeatureTests`

  - [x] 4.5 Implementar el resumen de cierre y la finalización
    - Implementar la propiedad calculada `completionSummary` derivada 1:1 de `content.shortcutSteps` (mismo orden y títulos), `skip()` (fija `isFinished` sin activar captura ni cerrar onboarding), `confirmCompletion()` y `retryAdvance()`
    - Manejar `summaryUnavailable = true` cuando `content == nil` al llegar a `.closing`, conservando el control de confirmar; fijar `advanceError` y mantener `.closing` + el resumen cuando el avance falla
    - _Requirements: 1.3, 6.1, 6.2, 6.3, 6.4_

  - [x] 4.6 Escribir prueba por propiedad para la correspondencia 1:1 del resumen de cierre
    - **Property 6: El resumen de cierre corresponde 1:1 con los pasos de configuración**
    - **Validates: Requirements 6.1**
    - Swift Testing con contenidos válidos de longitud variable de `shortcutSteps`, mínimo 100 iteraciones; etiqueta `Feature: apple-pay-setup-guide, Property 6`
    - Verificar `completionSummary.count == shortcutSteps.count` y correspondencia por índice preservando títulos

  - [x] 4.7 Escribir tests de edge cases de error del modelo
    - Con `content == nil`: `presentFirstScreen()` fija `presentationError` y no cambia de pantalla, y `retryPresentation()` reintenta (R1.5)
    - Con `isShortcutsAutomationAvailable == false`: el modelo expone el estado de incompatibilidad (R2.6)
    - Con `content == nil` al llegar a `.closing`: `summaryUnavailable == true` con confirmar disponible (R6.2)
    - Con avance fallido tras confirmar: `advanceError` fijo, `currentScreen == .closing`, resumen conservado (R6.4)
    - _Requirements: 1.5, 2.6, 6.2, 6.4_

  - [x] 4.8 Escribir tests de ejemplo de entrada, omitir y handlers
    - `presentFirstScreen()` con contenido válido deja `currentScreen == .requirements` (R1.2); `skip()` fija `isFinished` sin invocar avance ni captura (R1.3)
    - Con un espía del handler, `confirmCompletion()` en `Mode.onboarding` invoca `onOnboardingFinished` una vez (R6.3)
    - _Requirements: 1.2, 1.3, 6.3_

- [x] 5. Checkpoint — Modelo de la guía
  - Ensure all tests pass, ask the user if questions arise.

- [x] 6. Implementar las vistas de la guía
  - [x] 6.1 Implementar `GuiaApplePayView` y las subvistas de contenido
    - Crear `Sources/OnboardingFeature/GuiaApplePayView.swift` que hospeda la pantalla actual según `model.currentScreen` con botones "Atrás"/"Siguiente"/"Omitir" y "Confirmar" en cierre; sin lógica, solo refleja el modelo
    - Crear subvistas en `Components/`: `RequirementsStepView` (R5, siempre antes de los pasos), `ShortcutStepsView` (R2, lista numerada + mapeo de parámetros), `MatchingStepView` (R3, con botón "Abrir Ajustes → Tarjetas" que llama el handler inyectado), `LimitationsStepView` (R4) y `ClosingStepView` (R6, resumen con indicadores ícono + texto)
    - Agregar `#Preview` por tema (`LanaTheme.allCases`) usando `AppDependencies.preview()` e `InMemoryApplePayEnvironment`
    - _Requirements: 1.1, 2.1, 2.2, 2.3, 3.1, 3.2, 3.3, 3.4, 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 5.1, 5.2, 5.3, 6.1_

  - [x] 6.2 Implementar los estados de error de las vistas
    - Usar `EmptyStateView` de `LanaDesign` para: error de presentación con "Reintentar" (R1.5), Atajos no disponible (R2.6), resumen de cierre no disponible manteniendo confirmar (R6.2) y avance fallido con "Reintentar" (R6.4)
    - Definir `GuiaApplePayError: LocalizedError` con `contentUnavailable`, `automationUnsupported`, `onboardingAdvanceFailed` y mensajes en español; los indicadores de estado combinan ícono + texto, nunca solo color
    - _Requirements: 1.5, 2.6, 6.2, 6.4_

  - [x] 6.3 Implementar el contenedor `OnboardingModel` / `OnboardingView`
    - Crear `OnboardingModel` (`@MainActor @Observable`) con un arreglo de pasos extensible que incluye el punto de entrada visible y etiquetado "Configurar Apple Pay" (R1.1) y maneja "omitir" avanzando su propio paso sin cerrar el flujo (R1.3), exponiendo `onOnboardingFinished` hacia `ContentView`
    - Crear `OnboardingView` que presenta los pasos y la `GuiaApplePayView` en `Mode.onboarding`
    - _Requirements: 1.1, 1.3, 6.3_

  - [x] 6.4 Escribir tests de presencia de puntos de entrada
    - `OnboardingModel` incluye el punto de entrada de la guía (R1.1)
    - _Requirements: 1.1_

- [x] 7. Ensamblar en App / ContentView
  - [x] 7.1 Implementar `ApplePayEnvironmentProbe` real en el target de la app
    - Crear la implementación de `ApplePayEnvironmentProbing` que consulta el entorno del dispositivo/simulador (`isShortcutsAutomationAvailable`, `isRunningInSimulator`); su validación es manual en dispositivo (fuera de tests automatizados)
    - _Requirements: 2.6, 5.2_

  - [x] 7.2 Cablear el enrutamiento de onboarding y los handlers en `ContentView`
    - En `ContentView`/`RootView`, elegir entre onboarding y `MainTabView` según la bandera `"lana.hasCompletedOnboarding"` en `UserDefaults`
    - Inyectar `ApplePayEnvironmentProbe` real, `onOpenCardSettings` (abre el formulario de `CardsFeature`, mismo patrón que `onExpenseTap`), `onOpenShortcutsApp` (best-effort vía URL scheme) y `onOnboardingFinished` (fija la bandera y transiciona a `MainTabView`, reportando fallo al modelo si no puede)
    - _Requirements: 1.4, 3.4, 6.3, 6.4_

  - [x] 7.3 Agregar la fila de reingreso "Configurar Apple Pay" en Ajustes
    - En `SettingsModel`/`SettingsView`, agregar la fila que presenta la guía como hoja en `Mode.standalone`, cuyo `onFinish` cierra la hoja en lugar de avanzar el onboarding
    - _Requirements: 1.4_

- [x] 8. Checkpoint final — Integración completa
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Las tareas marcadas con `*` son opcionales (tests) y pueden omitirse para un MVP más rápido; las tareas de implementación central nunca se marcan opcionales.
- Cada tarea referencia los requisitos que satisface; las tareas de propiedad referencian explícitamente su propiedad del diseño.
- El testing usa Swift Testing (no XCTest) y prueba modelo y contenido, nunca la vista.
- Cada una de las seis propiedades de corrección se implementa con una única prueba por propiedad, con mínimo 100 iteraciones, etiquetada `Feature: apple-pay-setup-guide, Property {n}: {texto}`.
- Fuera de alcance de tests automatizados: latencias (R1.2 ≤1s, R6.1/R6.3 ≤2s) y la implementación real de `ApplePayEnvironmentProbing` (validación manual en dispositivo).
- Los checkpoints aseguran validación incremental antes de avanzar de capa.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2"] },
    { "id": 1, "tasks": ["1.3"] },
    { "id": 2, "tasks": ["1.4", "1.5", "1.6", "1.7", "1.8", "4.1"] },
    { "id": 3, "tasks": ["4.2"] },
    { "id": 4, "tasks": ["4.3", "4.5"] },
    { "id": 5, "tasks": ["4.4", "4.6", "4.7", "4.8"] },
    { "id": 6, "tasks": ["6.1", "6.2"] },
    { "id": 7, "tasks": ["6.3", "7.1"] },
    { "id": 8, "tasks": ["6.4", "7.2", "7.3"] }
  ]
}
```
