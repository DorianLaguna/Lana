# ADR-0043: Transcribir con SpeechAnalyzer y parsear lo finalizado mientras se dicta

- **Estado:** Aceptada
- **Fecha:** 2026-09-15

## Contexto

ADR-0015 metió la captura por voz con `SFSpeechRecognizer` + `AVAudioEngine`.
Funcionó, pero con dos costos que se hicieron visibles con el uso:

1. **Los cortes de segmento.** `SFSpeechRecognizer` on-device cierra su
   segmento tras una pausa y arranca otro desde cero, sin marcarlo como
   final. Para que el transcript no "se reiniciara" al hablar despacio hizo
   falta `TranscriptAccumulator`, que adivinaba cortes por timestamps y
   quitaba la repetición del arranque de cada segmento. Era la pieza más
   frágil del paquete.
2. **La espera al final.** El parser solo corría al tocar el micrófono.
   Si el monto o el concepto salían mal, el usuario se enteraba después de
   dictar todo, y había que dictar otra vez.

El usuario preguntó si la IA podía "escuchar" directamente. El modelo de
`FoundationModels` solo acepta texto, así que la pregunta real era qué tan
cerca se puede llegar sin romper ADR-0002 (on-device) ni el principio de "la
voz es otra forma de producir texto".

Alternativas consideradas:

- **Seguir con `SFSpeechRecognizer` y parsear con debounce** (si el texto no
  cambia en ~1 s, se parsea). Sin cambiar de API. Descartada:
  `SFSpeechRecognizer` no dice qué parte ya no va a cambiar, así que el
  debounce parsea hipótesis que el reconocedor luego reescribe, y el
  acumulador frágil se queda.
- **Un modelo en la nube con audio nativo** (tipo API realtime). La IA sí
  "oiría" el audio. Descartada de raíz: manda la voz y el ledger fuera del
  teléfono (ADR-0002) y agrega una dependencia externa y un backend.
- **`SpeechAnalyzer` + `SpeechTranscriber` (iOS 26) y parsear solo lo
  finalizado.** Elegida.

## Decisión

`AppleSpeechTranscribing` usa `SpeechAnalyzer` con un `SpeechTranscriber`
(`es-MX`, resultados volátiles + `fastResults`), alimentado por
`AVAudioEngine` a través de un `AVAudioConverter` al formato que pide el
analizador. El modelo del idioma se baja con `AssetInventory` la primera vez.
`SpeechTranscriber` es on-device por diseño: no existe un modo servidor al
que degradar.

El contrato de `SpeechTranscribing` cambia: `transcribe()` emite
`TranscriptSnapshot { text, finalizedText }` en vez de `String`.
`finalizedText` es el prefijo que el reconocedor ya no va a reescribir.
`AnalyzerTranscript` lo arma: concatena los resultados finales y pone detrás
el último volátil. `TranscriptAccumulator` se elimina.

`EntryModel` parsea `finalizedText` mientras se sigue escuchando
(`liveDrafts`), con un solo parseo a la vez: si llega texto nuevo mientras
corre uno, se toma el último al terminar. `ListeningView` muestra ese preview
en solo lectura. Al tocar el micrófono, si el último parseo en vivo fue sobre
exactamente el texto dictado, sus borradores pasan directo a revisión sin
parsear otra vez. Si no, se parsea la frase completa con el mismo `submit()`
de siempre.

Lo que sigue igual que en ADR-0015: la voz entra al mismo
`ExpenseParsing.parse(_:)`, la parada es manual (no hay detección de
silencio) y los permisos se piden la primera vez que se toca el micrófono.

## Consecuencias

**Bueno:**

- Desaparece la heurística de cortes de segmento: los resultados finales ya
  llegan marcados por la API.
- El usuario ve qué se entendió mientras sigue hablando y puede corregirse
  en voz antes de terminar.
- En el caso común, el parseo ya está hecho cuando se toca el micrófono, así
  que la revisión aparece al instante.
- Cero cambios al parser y ningún segundo camino de captura.

**Malo / a vigilar:**

- **Más llamadas al modelo.** Cada pausa dispara un parseo de todo lo
  finalizado. En un dictado largo con muchas pausas son varias sesiones de
  `FoundationModels` seguidas. Si se nota en batería o calor, conviene
  parsear solo cada N caracteres nuevos o esperar un mínimo entre parseos.
- **El parser ve frases a medias.** "gasté 300 en" puede producir un
  borrador raro durante un segundo. Es solo lectura y se reemplaza con el
  siguiente parseo, pero puede distraer. Si molesta, se puede mostrar el
  preview solo cuando el borrador trae monto y concepto.
- **La primera vez hay que bajar el modelo del idioma.** Mientras baja, la
  pantalla dice "Escuchando" sin transcribir. No hay indicador de progreso
  todavía (`AssetInstallationRequest.progress` existe si hace falta).
- **Se sigue pidiendo el permiso de reconocimiento de voz.** No está
  confirmado que `SpeechAnalyzer` lo necesite. Se mantiene para no
  arriesgar una regresión. Si en el iPhone se confirma que basta con el
  micrófono, quitarlo le ahorra un diálogo a quien llega nuevo.
- Igual que en ADR-0015, el audio real no se puede probar en `swift test`.
  `AnalyzerTranscript` y el flujo de `EntryModel` sí tienen pruebas. La
  conversión de audio y la bajada de assets se verifican a mano en el iPhone.
