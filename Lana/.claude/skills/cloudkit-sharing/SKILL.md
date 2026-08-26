---
name: cloudkit-sharing
description: Cómo implementar gastos compartidos en Lana con Core Data, NSPersistentCloudKitContainer y CKShare — zonas de registro, aceptación de invitaciones, permisos y el modelo de eventos append-only. Usa esta skill siempre que el trabajo toque listas compartidas, sincronización entre usuarios, saldos y deudas, participantes, o cualquier cosa relacionada con CloudKit sharing.
---

# Gastos compartidos

## Por qué Core Data y no SwiftData

SwiftData + CloudKit no soporta sharing (ver ADR-0004).
`NSPersistentCloudKitContainer` sí, con soporte nativo para Record Zone Sharing.
Core Data vive únicamente dentro de `LanaPersistence`, detrás del protocolo
`ExpenseStore`. Ninguna feature lo ve.

## Zonas de registro

**Los registros en la zona por defecto no se pueden compartir.** Esto no se
retrofitea: si guardas gastos personales en la zona default y luego quieres
compartirlos, hay que migrar datos de usuarios reales.

Por eso, desde el día 1:

- Gastos personales → zona privada del usuario
- Cada lista compartida → **su propia zona de registro personalizada**

Una zona por lista, no una zona para todas. Compartir es por zona, así que
mezclarlas significa compartir de más.

## Modelo append-only (ADR-0005)

Los saldos **nunca se guardan**. Siempre se derivan.

La razón: con last-write-wins de CloudKit, si dos personas editan gastos offline
y luego sincronizan, un saldo almacenado se corrompe en silencio. Y silencio en
dinero entre personas es lo peor que puede pasar.

Todo es un evento inmutable:

```
ExpenseAdded(id, listID, payerID, amount, currency, splitRule, at)
ExpenseCorrected(correctsID, ...)     // editar = corregir, no mutar
ExpenseVoided(voidsID, at)            // borrar = anular, no eliminar
SettlementRecorded(from, to, amount, currency, at)
```

Los eventos conmutan: el orden de llegada no altera el saldo final. Eso es lo que
hace que la sincronización sea segura sin coordinación.

El saldo se recalcula plegando todos los eventos de la lista. Cachéalo en memoria
si hace falta rendimiento, nunca en disco.

Bonus: te queda historial de auditoría completo. Cuando hay dinero entre personas,
poder mostrar "esto se registró el martes y se corrigió el jueves" vale mucho.

## Multi-moneda y deuda

La deuda se fija en **la moneda del gasto**. La conversión es solo presentación.

Si alguien pagó 100 USD y la división es mitad y mitad, la deuda es 50 USD, hoy y
en seis meses. Convertir al registrar significa que el saldo cambia solo cuando se
mueve el tipo de cambio — y eso es imposible de explicarle a un usuario molesto.

Guarda siempre: monto original, moneda original, y la tasa del día del gasto (para
mostrar, no para calcular).

## Aceptar invitaciones

El invitado abre el link y el sistema llama a
`userDidAcceptCloudKitShareWith` en el scene delegate. Hay que manejarlo aunque la
app esté cerrada — es el caso que más se olvida y produce un link que no hace nada.

Un registro solo puede estar en un share a la vez. Un segundo intento falla con
`alreadyShared`; captúralo y explícalo, no lo dejes reventar.

## Permisos

El dueño de la lista controla el acceso. Por defecto, tener el link no da acceso.

Para Lana: el dueño puede todo; los participantes agregan y corrigen sus propios
eventos, pero no anulan los de otros. Eso se aplica en la capa de dominio, no solo
en CloudKit.

## Trampas conocidas

**iCloud apagado.** Si el usuario no tiene sesión, la app cae a modo local y las
funciones de compartir se deshabilitan con un aviso claro. No revientes.

**Simulador.** CloudKit sharing se prueba mal en simulador. Necesitas dos devices
físicos con cuentas de iCloud distintas. Presupuesta ese tiempo.

**El parser en modo compartido.** "Cena 600, pagué yo, mitad y mitad" necesita
extraer pagador y regla de división además del monto. Es un `@Generable` distinto,
activado solo dentro de una lista compartida. Su accuracy es más baja que la del
parser simple — mídelos por separado en el golden set.
