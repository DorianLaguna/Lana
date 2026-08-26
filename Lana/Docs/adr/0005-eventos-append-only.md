# ADR-0005: Modelo de eventos append-only para gastos y saldos

- **Estado:** Aceptada
- **Fecha:** 2026-08-23

## Contexto

Con gastos compartidos y deudas entre participantes, dos personas pueden editar
datos offline y sincronizar después. CloudKit resuelve conflictos con
last-write-wins.

Si el saldo estuviera almacenado como un valor mutable, ese escenario lo corrompe
sin que nadie se entere. Un saldo silenciosamente equivocado entre dos personas
que se deben dinero es la peor falla posible de esta app — peor que un crash,
porque un crash se ve.

## Decisión

Los gastos, correcciones, anulaciones y liquidaciones son **eventos inmutables**
en un registro que solo crece.

- Editar un gasto emite un evento de corrección que referencia al original.
- Borrar emite un evento de anulación.
- Los saldos **nunca se persisten**. Se derivan plegando los eventos de la lista.
- Se puede cachear el saldo en memoria; jamás en disco.

Los eventos conmutan: el orden en que llegan no altera el estado final.

## Consecuencias

- La sincronización es segura sin coordinación entre devices.
- Queda historial de auditoría completo y gratis, que es exactamente lo que quieres
  poder mostrar cuando hay dinero entre personas.
- El almacenamiento crece monótonamente. Para el volumen de una app de gastos
  personales es irrelevante — miles de eventos son kilobytes.
- Calcular saldos cuesta más que leerlos. Se resuelve con caché en memoria; si un
  día no alcanza, la respuesta es un snapshot periódico, no mutar el modelo.
- El modelo de dominio es menos obvio para quien llega nuevo. Por eso existe este
  ADR.
