# ADR-0015: Captura por voz on-device, con parada manual

- **Estado:** Aceptada
- **Fecha:** 2026-08-26

## Contexto

`PLAN.md` y `CLAUDE.md` listaban "entrada por voz" como fuera de v1.0. El
usuario vio un rediseño (mockup en Claude Design) donde la captura es
voz-primero — un FAB de micrófono en el Dashboard reemplaza al tab de
Captura por texto — y pidió explícitamente construirlo ya, no dejarlo para
después. Esto mete alcance nuevo, así que toca decidir la forma, no solo
aceptar el pedido.

El riesgo real no es la UI, es la arquitectura: ADR-0002 fijó "solo Apple
Intelligence on-device, sin fallback a servidor" para el parseo. Si la
transcripción de voz cae a reconocimiento en servidor de Apple sin que
nadie lo note, se rompe el mismo principio por la puerta de atrás — el
usuario cree que todo su gasto (incluida la frase que dijo en voz alta)
se queda en el teléfono, y no sería cierto.

También hay una tentación de diseño a evitar: escribir un "segundo
parser" que entienda audio directamente. CLAUDE.md ya lo prohíbe para
tickets ("un ticket es solo otra forma de producir texto") — el mismo
razonamiento aplica a voz.

## Decisión

Voz es **otra forma de producir texto**, no un camino de parseo nuevo. El
flujo es: escuchar → transcribir → el transcript entra al mismo
`ExpenseParsing.parse(_:)` que ya existe para texto tecleado. Cero cambios
al parser.

Arquitectura:

- Protocolo nuevo `SpeechTranscribing` en `LanaCore` (mismo patrón que
  `ExpenseParsing`): `availability`, `requestPermission()`,
  `transcribe() -> AsyncThrowingStream<String, Error>` (snapshots
  crecientes del transcript), `stopTranscribing()`.
- Implementación concreta en paquete nuevo `LanaSpeech` (`SFSpeechRecognizer`
  + `AVAudioEngine`), igual que `LanaParsing` implementa `ExpenseParsing`.
- **On-device explícito**: `requiresOnDeviceRecognition = true` cuando
  `recognizer.supportsOnDeviceRecognition` es `true`. Si el dispositivo no
  lo soporta para `es-MX`, `SpeechAvailability` lo refleja como una
  limitación visible al usuario — **nunca** se degrada en silencio a
  reconocimiento en servidor. Es el mismo trato que ADR-0002 le da a
  Apple Intelligence: si no está disponible on-device, no está
  disponible, punto.
- **Parada manual, no detección de silencio.** El usuario toca el
  micrófono otra vez para terminar de dictar. Evita la complejidad (y los
  falsos cortes) de un detector de silencio, y coincide con el mockup ya
  aprobado ("toca el micrófono para terminar").
- Permisos de micrófono y de reconocimiento de voz se piden la primera
  vez que se toca el micrófono (JIT), no en un chequeo de disponibilidad
  al abrir la app — son permisos de usuario, no una capacidad del
  dispositivo como Apple Intelligence.

## Consecuencias

- El parser no se toca. El riesgo de este cambio vive contenido en
  `LanaSpeech`, un paquete nuevo que ninguna feature importa directamente
  (solo `EntryFeature`, vía el protocolo en `LanaCore`, igual que con
  `ExpenseParsing`).
- `PLAN.md`/`CLAUDE.md` actualizados: "voz" sale de fuera-de-v1.0.
- No hay forma de probar audio real en `swift test` (sin micrófono ni
  simulador de habla) — igual que `FoundationModels`, la verificación de
  punta a punta es manual, en el iPhone físico. Los tests de
  `LanaSpeech` cubren solo el mapeo puro de estados de autorización a
  `SpeechAvailability`.
- Queda como riesgo conocido, no resuelto aquí: si `es-MX` no soporta
  reconocimiento on-device en el dispositivo del usuario, la captura por
  voz queda inhabilitada para él (con mensaje claro) en vez de degradada.
  Es la consecuencia directa de no ceder en "on-device de verdad".
