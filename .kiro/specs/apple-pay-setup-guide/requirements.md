# Documento de Requisitos

## Introducción

Esta funcionalidad agrega una guía de configuración paso a paso, dentro del onboarding de Lana, que enseña al usuario final a activar la captura automática de transacciones de Apple Pay (ADR-0009). Como no existe una API de terceros para leer transacciones de Apple Pay, la captura depende de que el usuario arme por sí mismo una automatización en la app Atajos (Shortcuts), usando el disparador "Wallet", que llame al App Intent "Agregar transacción de Apple Pay" de Lana. Sin esta guía, la función es prácticamente inaccesible para la mayoría de los usuarios porque el flujo de Atajos no es evidente.

La guía debe cubrir tres cosas: (1) cómo crear la automatización de Atajos y conectar sus parámetros al App Intent, (2) cómo asegurar que las tarjetas de Lana emparejen con el nombre que Wallet reporta (alias, últimos 4 dígitos o `walletMatchHint`, según ADR-0019 y ADR-0031), y (3) qué esperar de la función, incluyendo sus limitaciones conocidas (solo NFC, toda transacción entra con `needsReview`, no se puede probar en el simulador).

Esta funcionalidad es solo la guía instructiva y su presentación dentro del onboarding. El App Intent, el emparejamiento de tarjetas y el campo `walletMatchHint` ya existen y no forman parte del alcance de este documento.

## Glosario

- **Guia_ApplePay**: La secuencia de pantallas dentro del onboarding de Lana que instruye al usuario para configurar la captura automática de Apple Pay. Es el sistema principal descrito en este documento.
- **Onboarding**: El flujo inicial de la app de Lana que presenta las funciones al usuario por primera vez.
- **App_Intent_AgregarTransaccion**: La acción de Lana expuesta a Atajos, titulada "Agregar transacción de Apple Pay", que registra un pago con `needsReview: true`.
- **Disparador_Wallet**: El disparador de automatización de la app Atajos, introducido en iOS 17 y renombrado a "Wallet" en iOS 26, que se activa al pagar con una tarjeta seleccionada y entrega monto, comercio y nombre de tarjeta.
- **App_Atajos**: La app Shortcuts de iOS donde el usuario construye la automatización.
- **Alias**: El nombre visible que el usuario le da a una tarjeta en Lana, usado en dashboard, picker de método de pago y captura por voz (ADR-0031).
- **NombreEnWallet**: El campo opcional `walletMatchHint` de una tarjeta en Lana, usado únicamente para emparejar con el texto que Wallet reporta cuando el nombre en Wallet difiere del alias visible (ADR-0031).
- **Ultimos4Digitos**: Los últimos cuatro dígitos de una tarjeta, la señal de mayor prioridad para el emparejamiento (ADR-0019).
- **needsReview**: El estado con el que entra toda transacción capturada vía Apple Pay, marcándola para revisión posterior en lugar de tratarla como dato confirmado (ADR-0009).
- **Captura_NFC**: Un pago con Apple Pay hecho por contacto físico (tap) en un terminal, el único tipo de pago que la automatización captura (ADR-0009).
- **Ajustes_Tarjetas**: La sección Ajustes → Tarjetas de Lana donde el usuario edita el alias, el NombreEnWallet y los datos de cada tarjeta.

## Requisitos

### Requisito 1: Punto de entrada de la guía en el onboarding

**Historia de Usuario:** Como usuario nuevo, quiero encontrar la guía de configuración de Apple Pay dentro del onboarding, para poder activar la captura automática sin buscarla por mi cuenta.

#### Criterios de Aceptación

1. WHILE el usuario recorre el Onboarding, THE Guia_ApplePay SHALL mostrar de forma visible un punto de entrada, etiquetado y seleccionable, para configurar la captura automática de Apple Pay en al menos una de las pantallas del Onboarding.
2. WHEN el usuario selecciona el punto de entrada de la Guia_ApplePay, THE Guia_ApplePay SHALL mostrar la primera pantalla de instrucciones en un máximo de 1 segundo.
3. WHEN el usuario elige omitir la Guia_ApplePay, THE Onboarding SHALL continuar al siguiente paso sin activar la captura de Apple Pay y sin cerrar el flujo de Onboarding.
4. WHERE el Onboarding ha finalizado, THE Guia_ApplePay SHALL ofrecer un punto de entrada persistente y seleccionable dentro de la aplicación para reabrir la guía.
5. IF la Guia_ApplePay no puede mostrar la primera pantalla de instrucciones tras seleccionar el punto de entrada, THEN THE Guia_ApplePay SHALL mostrar un mensaje de error que indique el fallo, mantener al usuario en el paso actual del Onboarding y ofrecer la opción de reintentar.

### Requisito 2: Instrucciones para armar la automatización de Atajos

**Historia de Usuario:** Como usuario, quiero instrucciones paso a paso para crear la automatización en Atajos, para conectar el disparador de Wallet con la acción de Lana.

#### Criterios de Aceptación

1. THE Guia_ApplePay SHALL presentar una secuencia numerada y ordenada de pasos que cubra, como mínimo: (a) abrir la App_Atajos, (b) crear una automatización nueva, (c) seleccionar el Disparador_Wallet, (d) agregar la acción del App_Intent_AgregarTransaccion y (e) guardar la automatización.
2. THE Guia_ApplePay SHALL indicar que la automatización debe invocar el App_Intent_AgregarTransaccion, identificado con el título exacto "Agregar transacción de Apple Pay".
3. THE Guia_ApplePay SHALL indicar el mapeo de cada parámetro entregado por el Disparador_Wallet al parámetro correspondiente del App_Intent_AgregarTransaccion: monto al parámetro de monto, comercio al parámetro de comercio y nombre de tarjeta al parámetro de nombre de tarjeta.
4. THE Guia_ApplePay SHALL indicar que el usuario debe crear una automatización independiente por cada tarjeta física que desee capturar, identificando cada automatización por el nombre de la tarjeta correspondiente.
5. THE Guia_ApplePay SHALL indicar que la automatización debe configurarse para ejecutarse de inmediato sin solicitar confirmación, de modo que la captura de la transacción ocurra sin abrir ni mostrar la app de Lana.
6. IF el Disparador_Wallet o la App_Atajos no están disponibles en el dispositivo del usuario, THEN THE Guia_ApplePay SHALL mostrar un mensaje que indique que la automatización no puede crearse por falta de compatibilidad y describa la condición requerida para continuar.

### Requisito 3: Selección de tarjetas y emparejamiento con Wallet

**Historia de Usuario:** Como usuario, quiero entender cómo seleccionar mis tarjetas y cómo Lana las empareja con lo que reporta Wallet, para que cada pago se registre en la tarjeta correcta.

#### Criterios de Aceptación

1. THE Guia_ApplePay SHALL explicar que Lana empareja el nombre de tarjeta que reporta Wallet contra las tarjetas registradas usando, en orden de prioridad, primero los Ultimos4Digitos (los últimos 4 dígitos de la tarjeta) y, si no hay coincidencia por dígitos, el Alias o el NombreEnWallet.
2. WHERE el nombre que Wallet reporta para una tarjeta difiere del Alias visible, THE Guia_ApplePay SHALL indicar que el usuario debe registrar ese nombre en el campo NombreEnWallet en Ajustes_Tarjetas.
3. IF ninguna tarjeta registrada empareja con el nombre que reporta Wallet, THEN THE Guia_ApplePay SHALL indicar que la automatización falla y que el usuario debe revisar el Alias, el NombreEnWallet y los Ultimos4Digitos de sus tarjetas en Ajustes_Tarjetas.
4. THE Guia_ApplePay SHALL ofrecer un enlace a Ajustes_Tarjetas para que el usuario edite los datos de emparejamiento de sus tarjetas.

### Requisito 4: Comunicación de limitaciones conocidas

**Historia de Usuario:** Como usuario, quiero conocer las limitaciones de la captura automática de Apple Pay, para no confundir su comportamiento esperado con un error.

#### Criterios de Aceptación

1. THE Guia_ApplePay SHALL mostrar un mensaje visible que informe que solo se capturan de forma automática los pagos de tipo Captura_NFC y que las compras hechas en navegador no se capturan por esta vía y deben registrarse manualmente.
2. THE Guia_ApplePay SHALL mostrar un mensaje visible que informe que toda transacción capturada por esta vía entra con estado needsReview y requiere revisión manual antes de considerarse confirmada.
3. THE Guia_ApplePay SHALL mostrar un mensaje visible que informe que el Disparador_Wallet puede registrar transacciones rechazadas debido a fallas conocidas.
4. THE Guia_ApplePay SHALL mostrar un mensaje visible que informe que el Disparador_Wallet puede registrar transacciones duplicadas debido a fallas conocidas.
5. THE Guia_ApplePay SHALL indicar que, por las fallas conocidas del Disparador_Wallet, el usuario debe revisar cada transacción capturada.
6. THE Guia_ApplePay SHALL informar que la captura automática es una conveniencia y que la captura manual sigue siendo el camino principal y obligatorio de registro.

### Requisito 5: Requisito de dispositivo físico

**Historia de Usuario:** Como usuario, quiero saber que necesito un dispositivo físico para usar esta función, para no intentar configurarla donde no puede funcionar.

#### Criterios de Aceptación

1. THE Guia_ApplePay SHALL mostrar un mensaje que indique que la captura automática de Apple Pay requiere un dispositivo físico iOS con al menos una tarjeta agregada a Wallet.
2. THE Guia_ApplePay SHALL mostrar un mensaje que indique que la captura automática de Apple Pay no puede probarse en el simulador de iOS porque no permite agregar tarjetas a la Wallet simulada.
3. WHEN el usuario abre la Guia_ApplePay, THE Guia_ApplePay SHALL mostrar el requisito de dispositivo físico y la limitación del simulador antes de presentar los pasos de configuración.

### Requisito 6: Confirmación de finalización de la guía

**Historia de Usuario:** Como usuario, quiero una confirmación al terminar la guía, para saber que completé la configuración y qué esperar a continuación.

#### Criterios de Aceptación

1. WHEN el usuario llega al final de la Guia_ApplePay, THE Guia_ApplePay SHALL mostrar, en un máximo de 2 segundos, una pantalla de cierre que liste cada paso de configuración completado con su indicador de estado (completado) y una descripción del siguiente paso del Onboarding.
2. IF al llegar al final de la Guia_ApplePay el estado de los pasos completados no está disponible, THEN THE Guia_ApplePay SHALL mostrar la pantalla de cierre con un mensaje indicando que el resumen no pudo cargarse, y SHALL mantener disponible el control de confirmación.
3. WHEN el usuario activa el control de confirmación de la pantalla de cierre de la Guia_ApplePay, THE Onboarding SHALL avanzar al siguiente paso en un máximo de 2 segundos.
4. IF el avance del Onboarding falla tras la confirmación, THEN THE Onboarding SHALL permanecer en la pantalla de cierre, SHALL mostrar un mensaje indicando que el avance no pudo completarse, y SHALL conservar el estado de los pasos completados para permitir un nuevo intento.
