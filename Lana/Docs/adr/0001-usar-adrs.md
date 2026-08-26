# ADR-0001: Registrar decisiones de arquitectura

- **Estado:** Aceptada
- **Fecha:** 2026-08-23

## Contexto

Este proyecto lo desarrolla una sola persona a lo largo de varios meses, con
pausas. El costo real no es escribir el código, es recordar por qué el código
quedó así. Sin registro, cada regreso al proyecto arranca con arqueología.

Además, buena parte del trabajo se hace con asistencia de Claude Code, que llega
a cada sesión sin memoria del proyecto. Un registro escrito de decisiones es lo
que le da contexto sin tener que reconstruirlo cada vez.

## Decisión

Toda decisión que afecte estructura, dependencias, modelo de datos o límites de
plataforma se registra como un ADR en `Docs/adr/`, numerado secuencialmente.

Los ADRs son inmutables. Una decisión que cambia no se edita: se escribe un ADR
nuevo que marca al anterior como superseded.

El ADR va en el mismo PR que el cambio que documenta.

## Consecuencias

- Cada cambio estructural cuesta ~10 minutos extra de escritura.
- A cambio, la pregunta "¿por qué esto es así?" siempre tiene respuesta.
- El historial de ADRs es la memoria del proyecto para cualquier colaborador,
  humano o no.
