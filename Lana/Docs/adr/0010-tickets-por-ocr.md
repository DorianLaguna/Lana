# ADR-0010: Escaneo de tickets con OCR, no con el modelo multimodal

- **Estado:** Aceptada
- **Fecha:** 2026-08-23

## Contexto

Se quiere fotografiar un ticket y que la transacción se registre sola.

Hay dos caminos. El modelo on-device acepta imágenes en el prompt a partir de
iOS 27, lo que permitiría pasarle la foto directamente. La alternativa es OCR con
Vision y alimentar el texto resultante al parser que ya existe.

El proyecto tiene mínimo iOS 26. Subirlo a iOS 27 reduciría todavía más un público
ya restringido por el requisito de Apple Intelligence (ADR-0002).

## Decisión

OCR con Vision y VisionKit, alimentando el `ExpenseParsing` existente.

Un ticket escaneado produce **una** transacción con el total. El desglose por
renglón es una acción opcional, no el comportamiento por defecto.

Se adjunta una miniatura comprimida (JPEG, lado mayor 1000px, objetivo <150 KB),
almacenada como binario externo para que sincronice como asset.

Todo lo capturado por escaneo entra con `needsReview`.

## Consecuencias

- No sube el mínimo de iOS.
- Vision no requiere Apple Intelligence, así que el OCR funciona incluso en devices
  donde el resto del parseo no. No cambia el requisito general de la app, pero
  simplifica el código.
- Se reutiliza el parser existente. La feature cuesta días, no semanas.
- La calidad depende del papel térmico y del estado del ticket. Habrá fallas que no
  son corregibles desde el código; por eso `needsReview` es obligatorio.
- Elegir el total correcto entre subtotal, IVA, propina y cambio requiere heurística
  propia además del modelo. La respuesta del modelo se valida contra los montos que
  el OCR realmente encontró.
- Cuando iOS 27 sea piso razonable, pasar la imagen directa al modelo es una mejora
  detrás del mismo protocolo, sin cambios para el resto del sistema.
- La miniatura no sirve como comprobante fiscal. Es referencia visual para corregir.
