# ADR-0033: El monto de Apple Pay también se acepta como texto, y sin monto no se guarda nada

- **Estado:** Aceptada
- **Fecha:** 2026-09-01

## Contexto

El atajo de Apple Pay (ADR-0009/ADR-0019) empezó a disparar de verdad y
guardó un gasto inservible: concepto "Apple Pay", categoría vacía y **monto
0**. La tarjeta sí hizo match, o sea que `walletCardName` llegó completo.

El atajo estaba bien armado — el usuario mandó captura de la automatización
con los tres campos conectados a sus variables ("Cantidad pago", "Comercio",
"Tarjeta o pase").

La primera hipótesis fue conversión de tipo: `walletCardName` y `merchant`
son `String` y Shortcuts convierte cualquier variable a texto, pero `amount`
es `Double` y una cantidad con moneda ("$149.99") no se convertiría. **Esa
hipótesis no se sostiene**: el comercio era AutoZone, un comercio normal, y
`merchant` también es `String` y también llegó vacío. Si fuera el tipo, la
tarjeta habría fallado igual.

Lo que sí quedó establecido, leyendo el código: `walletCardName` llegó con
contenido real. `Card.init` normaliza un `walletMatchHint` vacío a `nil` y el
alias no puede ser vacío, así que un texto vacío no habría encontrado
ninguna tarjeta — habría lanzado `cardNotFound` sin guardar nada. El gasto se
guardó, luego la tarjeta hizo match de verdad.

Queda entonces una pregunta abierta que no se puede contestar desde el
código: **por qué `Tarjeta o pase` sí resuelve y `Comercio`/`Cantidad` no**,
siendo variables de la misma transacción. La sospecha razonable es que al
momento del tap NFC la transacción todavía no tiene monto ni comercio —
esos los confirma el emisor cuando el cargo se asienta, después — y encaja
con lo que Docs/CLAUDE.md ya advierte del trigger ("se pasa de tiempo y
dispara hasta en pagos rechazados"). Pero es una sospecha, no un hecho
verificado.

El usuario propuso pasarle la transacción entera a Apple Intelligence y que
el modelo parsee todo.

## Decisión

**El monto se acepta también como texto, y lo lee el regex, no el modelo.**
`AddTransactionIntent` gana un parámetro opcional `amountText`, donde se
conecta la MISMA variable de monto. Un `String` sobrevive la conversión de
Shortcuts siempre. Esto cubre el caso de conversión de tipo **si es que
existe** — descartada como causa de este reporte, pero barata de tener.

**Se acepta también la transacción completa, y esa sí pasa por el modelo.**
`transactionText` es el respaldo más amplio: cuando el comercio o el monto
no llegan por sus campos, ese texto entra al MISMO `parse(_:)` de la captura
por voz. No es un segundo parser (Docs/CLAUDE.md), y no rompe la regla del
monto: `parse(_:)` corre `ParsingPipeline` por dentro, donde el regex de
`AmountValidator` valida contra el texto crudo lo que el modelo propuso.

El orden de confianza para el monto queda: campo numérico → campo de texto →
lo que el parser sacó de la transacción → regex crudo sobre la transacción,
y este último **solo si el texto trae un único número**. Con varios (unos
últimos 4 dígitos, un folio) no hay forma de saber cuál es el monto, y
adivinar dinero no se hace. El comercio, si llegó, manda sobre lo que el
modelo dedujo: es dato directo, no interpretación.

**Los errores del intent conforman a `CustomLocalizedStringResourceConvertible`.**
Sin eso no se lee ninguno: App Intents ignora `errorDescription` de
`LocalizedError` y Shortcuts muestra su genérico ("la app encontró un
error"). El usuario probó un pago real y eso fue justo lo que vio — todo el
diagnóstico de abajo existía y no llegaba a ningún lado. Además se envuelven
las fallas de arranque del store (`setupFailed`), para que un problema de
Core Data/CloudKit no se vea idéntico a un atajo mal armado.

**El intent reporta lo que recibió.** Mientras no se sepa por qué unas
variables llegan y otras no, lo único que separa "la variable no está
conectada" de "está conectada y Wallet la entrega vacía" es ver los valores
crudos. El error de monto faltante los incluye (`receivedDiagnostic`), y se
lee en Shortcuts, que es donde está quien arma la automatización. Es
diagnóstico, no copy de producto.

La propuesta de mandar todo al modelo se toma **a medias, a propósito**:

- **Concepto y categoría sí** — ya era así desde ADR-0019: el comercio pasa
  por `parse(_:)` solo para sugerir categoría/subcategoría.
- **El monto no.** Docs/CLAUDE.md es explícito: "el regex gana sobre el
  modelo en el monto; `AmountValidator` corre siempre sobre el texto crudo".
  Además el intent corre en segundo plano sin abrir la app: si el modelo no
  está disponible (`availability != .available`, que ya se chequea) se
  perdería el dato más importante del pago. El regex no depende de nada.

La resolución vive en `AmountValidator.resolveAmount(numeric:text:)`
(`LanaParsing`), no en el intent: es lógica real, y en el target de la app
no se puede probar sin simulador — la máquina de desarrollo no logra crear
uno. En el paquete corre con `swift test`, que es donde el proyecto prueba
todo lo demás.

**Sin monto usable, el intent falla en vez de guardar.** Antes guardaba el
$0. Un pago de $0 no existe (mismo criterio que `ParsingPipeline`, que
descarta los de monto ≤ 0) y deja al usuario cazando basura en su lista. Es
un error de configuración, igual que `cardNotFound`, y se reporta en
Shortcuts donde sí se puede arreglar.

Esto **no** contradice "guardar nunca se bloquea" (Docs/CLAUDE.md): esa regla
protege una captura real cuyo parseo salió ambiguo. Aquí no hay captura — no
llegó ningún monto que guardar.

## Consecuencias

**Bueno:**

- El atajo funciona sin depender de cómo Shortcuts tipe la variable de
  monto: si el campo numérico falla, el de texto lo salva.
- Un atajo mal armado se nota al momento, en Shortcuts, en vez de ensuciar
  la lista de gastos con transacciones de $0.
- El monto sigue sin pasar por el modelo, así que la captura automática no
  se rompe cuando Apple Intelligence no está disponible.

**Malo / a vigilar:**

- **Son dos campos para un solo dato**, y el segundo solo existe por una
  limitación de conversión de Shortcuts que no podemos ver desde el código.
  Si algún día `Double` recibe bien la cantidad, `amountText` queda como
  ruido en la UI del atajo.
- Del texto se toma el **primer** número. El campo está documentado para
  recibir la variable de monto, no una frase; si alguien le conecta la
  transacción entera y esa empieza con otro número (unos últimos 4 dígitos,
  por ejemplo), se guardaría ese. Queda `needsReview` como red, pero el dato
  estaría mal.
- No se pudo verificar en el dispositivo: no hay forma de simular el trigger
  de Wallet desde aquí, y esta máquina no puede crear simuladores
  ("stuck in creation state"), así que ni siquiera corren los tests del
  target de la app. Lo cubierto son los tests de `resolveAmount` en
  `LanaParsing`; que la variable de Shortcuts efectivamente llegue como
  texto legible lo confirma el usuario con un pago real.
- **La causa raíz sigue sin identificarse.** Este ADR documenta dos
  mitigaciones (aceptar el monto como texto, reportar lo recibido), no un
  arreglo: no se sabe por qué `Comercio` y `Cantidad` llegan vacíos y
  `Tarjeta o pase` no. Si resulta que Wallet simplemente no tiene esos datos
  al momento del tap, ninguna de las dos sirve y la captura automática de
  Apple Pay se queda en "hubo un pago con esta tarjeta a esta hora" — mucho
  menos de lo que ADR-0009 asumió, y habría que decidir si eso vale la pena
  como feature o se replantea.
