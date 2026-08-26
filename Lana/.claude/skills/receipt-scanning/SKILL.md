---
name: receipt-scanning
description: Escaneo de tickets en Lana con Vision (OCR on-device) alimentando el parser existente, más el manejo de la miniatura adjunta. Usa esta skill siempre que el trabajo toque escanear o fotografiar tickets, OCR, VisionKit, extracción de totales de un recibo, o adjuntar imágenes a una transacción.
---

# Escaneo de tickets

## El principio

Un ticket es solo otra forma de producir texto. No hay un parser nuevo:

```
foto → VisionKit (recorte y enderezado) → Vision OCR → texto → ExpenseParsing
```

El mismo `@Generable` que procesa "300 de súper" procesa el texto del ticket. Si te
encuentras escribiendo un segundo parser para recibos, algo está mal.

## Por qué OCR y no el modelo con imágenes

El modelo on-device acepta imágenes a partir de iOS 27, pero el mínimo del proyecto
es iOS 26 y subirlo cierra más un embudo ya angosto (ADR-0010).

Ventaja adicional: Vision **no requiere Apple Intelligence**. Corre en cualquier
iPhone. Cuando iOS 27 sea piso razonable, pasar la imagen directa al modelo es una
mejora interna detrás de `ExpenseParsing` — nada más se entera.

## Elegir el total

El error clásico. Un ticket trae subtotal, IVA, descuentos, total, propina
sugerida y cambio.

Heurística: busca líneas que contengan "TOTAL"; si hay varias, toma la de mayor
monto (el subtotal siempre es menor). Descarta explícitamente líneas con "SUBTOTAL",
"IVA", "CAMBIO", "EFECTIVO", "SU PAGO", "PROPINA SUGERIDA".

Pásale al modelo el texto completo con instrucción de identificar el total pagado,
pero **valida su respuesta contra los montos que el OCR encontró**. Si el modelo
devuelve un número que no aparece en el texto, lo inventó — descártalo.

## Todo entra con `needsReview`

Sin excepción. El papel térmico se decolora y se arruga, los tickets de tienda de
conveniencia vienen impresos flojos, y la propina de restaurante suele estar escrita
a mano. El OCR va a fallar seguido y no es un bug que puedas arreglar.

Se presenta como sugerencia lista para confirmar, nunca como dato guardado.

## Un gasto, no cuarenta

Un ticket de súper se convierte en **una** transacción con el total.

El desglose por renglón existe como acción opcional, no como comportamiento por
defecto. Revisar 40 renglones categorizados cada vez que vas al súper es exactamente
el tedio del que este producto quiere escapar.

## La miniatura

Se guarda una miniatura comprimida, no la foto original:

- JPEG, lado mayor máximo 1000px, calidad ~0.6
- Objetivo: menos de 150 KB por ticket
- En Core Data con `allowsExternalBinaryDataStorage`, para que sincronice como
  asset y no infle el store

Importa porque el almacenamiento sale de la cuota de iCloud del usuario. Mil
tickets a 150 KB son 150 MB; a foto completa serían varios gigas y el usuario
culparía a tu app por llenarle el iCloud.

La miniatura es para verificar después, no para archivo fiscal. Si alguien
necesita el ticket original para deducir impuestos, eso es otro producto.

## Flujo en la UI

`VNDocumentCameraViewController` de VisionKit da el escáner nativo con recorte y
enderezado automáticos. No construyas cámara propia.

Después del escaneo, la pantalla de confirmación muestra la miniatura al lado de los
campos parseados. Ver la foto junto al monto es lo que hace que corregir sea rápido.
