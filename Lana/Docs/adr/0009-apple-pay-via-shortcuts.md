# ADR-0009: Captura de Apple Pay vía App Intent y Shortcuts

- **Estado:** Aceptada
- **Fecha:** 2026-08-23

## Contexto

Se quiere que las compras con Apple Pay se registren solas y se asignen a la
tarjeta correcta.

No existe API que permita a una app de terceros leer transacciones de Apple Pay.
Lo que existe es un disparador de automatización en Shortcuts, introducido en
iOS 17 y renombrado a "Wallet" en iOS 26, que se activa al pagar con una tarjeta
seleccionada y puede entregar monto, comercio y tarjeta a una acción de app.

## Decisión

Lana expone un App Intent de "Agregar transacción". El usuario arma la
automatización en Shortcuts eligiendo sus tarjetas.

Esto mueve App Intents de v1.1 a v1.0.

La app incluye una guía de configuración paso a paso dentro del onboarding. Sin
ella, la función no existe para la mayoría de los usuarios: el trabajo de armado
recae en ellos y el flujo de Shortcuts no es obvio.

## Consecuencias

- Solo captura pagos NFC. Las compras en navegador se registran a mano, y hay que
  decirlo en la guía para que la ausencia no se lea como bug.
- El disparador tiene fallas conocidas y abiertas: se pasa de tiempo cuando el
  banco tarda en notificar, y se activa incluso en transacciones rechazadas.
  Consecuencia de diseño: **toda transacción capturada así entra con
  `needsReview`**, nunca como dato confirmado.
- No se puede probar en simulador — no se pueden agregar tarjetas al Wallet
  simulado. Requiere device físico.
- La confiabilidad depende de Apple y del banco emisor. La función se presenta
  como conveniencia, nunca como la fuente de verdad del registro. La captura
  manual sigue siendo el camino principal.
