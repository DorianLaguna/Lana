# ADR-0057: Llevar la captura a la pantalla bloqueada con un Control, no solo con un widget

- **Estado:** Aceptada
- **Fecha:** 2026-09-17

## Contexto

ADR-0018 dejó la captura a un toque desde la pantalla de inicio: un widget
chico que abre `lana://capture`. El usuario pidió lo mismo pero **antes de
desbloquear**: "un botón que puedo presionar desde antes de desbloquear el
celular... que haga lo mismo, abra la app ya con el mic".

En la pantalla bloqueada de iOS hay dos lugares distintos para eso, y no son
la misma tecnología:

- **La fila bajo el reloj** — widgets accesorios (`accessoryCircular`), los
  mismos que el clima y la batería. Es WidgetKit, exactamente lo que ya
  existe: agregar una familia soportada y adaptar el dibujo.
- **Los botones de abajo** — junto a la linterna y la cámara. Desde iOS 18 no
  son widgets sino **Controls** (`ControlWidget`). La misma pieza aparece
  además en el Centro de Control y se puede asignar al Botón de Acción.

El usuario pidió los dos.

**Por qué esto reabre lo de App Intents.** ADR-0018 eligió deep link sobre
`AppIntent` a propósito, por ser el camino más simple. Un Control no deja
elegir: la acción de un `ControlWidgetButton` **tiene que** ser un
`AppIntent` — no acepta un `Link` ni una URL suelta. Así que un intent es
obligatorio aquí, no una preferencia.

**Alternativas consideradas:**

- **Solo el widget accesorio bajo el reloj.** Descartada como respuesta
  completa: es lo más barato, pero no es "el botón" que se pidió — vive
  arriba, compite con el clima por un lugar en esa fila, y no llega ni al
  Centro de Control ni al Botón de Acción.
- **Un `AppIntent` completo, expuesto a Siri y Atajos.** Descartada: ADR-0018
  ya dejó fuera de v1.0 la superficie de Siri (frases, parámetros,
  `IntentDescription` de cara al usuario). El intent que se agrega aquí va con
  `isDiscoverable = false` — existe para el control, no para el ecosistema.
- **Que el intent haga el trabajo en vez de abrir la app.** Imposible por la
  misma razón que en ADR-0018: grabar audio necesita la app en primer plano.
- **Un intent que abra la app y arranque a escuchar por su cuenta.**
  Descartada: duplicaría el camino de ADR-0018 con un segundo mecanismo para
  el mismo estado. El intent reenvía a `lana://capture` con `OpenURLIntent` —
  el deep link sigue siendo el único contrato entre la extensión y la app.

## Decisión

Un `ControlWidget` (`LanaCaptureControl`) en el mismo bundle de la extensión,
con un `ControlWidgetButton` cuya acción es `OpenCaptureIntent`: un
`AppIntent` con `openAppWhenRun = true` e `isDiscoverable = false`, cuyo
`perform()` no hace más que devolver `OpenURLIntent(lana://capture)`. Cero
lógica propia — la app lo recibe en el mismo `.onOpenURL` de ADR-0018.

El widget que ya existía suma `.accessoryCircular` a sus familias. La misma
vista con dos dibujos: en la pantalla de inicio, la moneda en `onAccent`
sobre el `accentFill` del tema; en la pantalla bloqueada, sin color propio y
con `AccessoryWidgetBackground()`, porque el sistema pinta esa fila en su modo
desteñido y un acento ahí no sobrevive.

El glifo es una moneda (`dollarsign.circle.fill`) y no el micrófono, en las
tres superficies — pedido del usuario, 2026-09-17. Con `$` y no con `₱`
(`pesosign`, que es el peso filipino) porque `$` es como la app escribe el
dinero en `es_MX`/MXN (ADR-0047). El texto sigue diciendo "Dictar un gasto":
el dibujo identifica de qué app es el botón, la palabra dice qué hace.

El toque pasa de `Link` a `.widgetURL`: en un widget chico y en uno accesorio
la superficie entera es un solo destino y el sistema solo respeta
`.widgetURL` — `Link` es para los tamaños mediano y grande.

La URL sale de las vistas a `LanaCaptureLink.url`, compartida por el widget y
el control: dos literales `lana://capture` en archivos distintos es una
separación esperando a pasar.

El control no lleva el color del tema. Un Control lo tiñe el sistema, igual
que la linterna; forzar el acento ahí lo haría ver ajeno entre sus vecinos.

## Consecuencias

**Bueno:**

- El atajo existe en cuatro lugares (inicio, bajo el reloj, botones de la
  pantalla bloqueada, Centro de Control y Botón de Acción) con un solo
  destino: `lana://capture`. Agregar una superficie más no agrega un camino
  de captura más.
- La app no cambió nada: ni `MainTabView`, ni `EntryModel`, ni el `Info.plist`.
  Todo lo nuevo vive en la extensión.

**Malo / a vigilar:**

- **Presionarlo con el teléfono bloqueado igual pide Face ID.** iOS no abre
  una app en primer plano sin desbloquear, y grabar audio necesita primer
  plano. Lo que se gana es no tener que buscar la app después del desbloqueo;
  no se gana registrar sin desbloquear. Si algún día se quiere de verdad
  capturar sin desbloquear, eso no es un control: es otra decisión, mucho
  mayor.
- Ya hay un `AppIntent` en la extensión. La barrera de ADR-0018 contra la
  superficie de App Intents ahora es solo `isDiscoverable = false` — la
  próxima vez que se proponga exponer algo a Siri, se decide de nuevo, sin
  la excusa de que "no hay intents".
- El widget accesorio no puede mostrar nada del tema del usuario, igual que
  el de inicio (sin App Group). En la pantalla bloqueada además ni siquiera
  puede intentarlo.
- Sin verificación en dispositivo real dentro de esta sesión más allá de que
  compila: que el sistema ofrezca el control al editar la pantalla bloqueada,
  y que abra la app escuchando desde ahí, necesita la prueba manual en el
  iPhone.
