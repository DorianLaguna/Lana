# ADR-0004: Core Data + CKShare para gastos compartidos

- **Estado:** Aceptada
- **Fecha:** 2026-08-23

## Contexto

Los gastos compartidos con saldos y deudas entran en v1.0. Hay tres formas de
sincronizar datos entre usuarios sin construir un backend propio:

**A) SwiftData + CloudKit.** El stack más limpio de escribir. Descartado por un
hecho duro: la integración de SwiftData con CloudKit no soporta sharing. Se puede
implementar `CKShare` a mano sobre SwiftData, pero es un patrón sin documentación
oficial y toda la sincronización queda de nuestro lado.

**B) Core Data + `NSPersistentCloudKitContainer`.** Soporta Record Zone Sharing de
forma nativa, con API para el scope `.shared` y acceso directo al `CKShare` de un
objeto. Es el camino documentado y con proyecto de ejemplo de Apple. El costo es
que Core Data es más verboso que SwiftData.

**C) Supabase con listas compartidas anónimas.** Se consideró seriamente: permite
seguir con SwiftData y abre la puerta a Android. Requiere cifrado del lado del
cliente para no perder el argumento de privacidad, e implica ~$25 USD al mes
perpetuos contra un ingreso de pago único.

## Decisión

Core Data con `NSPersistentCloudKitContainer` y `CKShare` (opción B).

Se descartó Supabase (C) porque Android no está en el horizonte, y sin Android su
única ventaja real desaparece mientras el costo mensual permanece.

Core Data queda confinado a `LanaPersistence`, detrás del protocolo `ExpenseStore`
de `LanaCore`. Ninguna feature ni el dominio saben que existe.

Los gastos personales viven en la zona privada del usuario. Cada lista compartida
vive en su propia zona de registro personalizada, decidido desde el diseño inicial
porque los registros de la zona por defecto no se pueden compartir y migrar
después significaría tocar datos de usuarios reales.

## Consecuencias

- Más código de persistencia que con SwiftData. Encapsulado, pero real.
- Cero costo de infraestructura y cero mantenimiento de servidor.
- El argumento de privacidad queda intacto: ningún dato pasa por servidores
  nuestros. Es una ventaja sobre MonAi, que sí procesa en la nube.
- Android queda cerrado permanentemente. Es una decisión consciente, no un
  descuido: si Android llega a importar, esto se reevalúa con un ADR nuevo y el
  costo será una migración completa de la capa de datos.
- Probar sharing requiere dos devices físicos con cuentas de iCloud distintas.
  El simulador no alcanza.
