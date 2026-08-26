# ADR-0003: Evaluar el parser con un golden set, no con tests pass/fail

- **Estado:** Aceptada
- **Fecha:** 2026-08-23

## Contexto

El parser depende de un modelo de lenguaje no determinista que además es
actualizado por Apple fuera de nuestro control. Un test tradicional de igualdad
exacta sería intermitente y se rompería con cada actualización de iOS, sin
distinguir entre una regresión real y una variación aceptable.

## Decisión

El parser se evalúa contra un conjunto fijo de frases reales en español mexicano
(`Tests/Fixtures/golden-set.json`), cada una con su resultado esperado.

La suite reporta accuracy por campo y falla solo si cae debajo del umbral:

- Monto: 90%
- Categoría: 80%
- Concepto: evaluación cualitativa, sin umbral

El golden set corre en CI y en cada beta de iOS.

## Consecuencias

- Detectamos degradación del modelo el día que sale la beta, no cuando se quejan
  los usuarios.
- El golden set hay que curarlo a mano y crece con el uso real. Es trabajo
  continuo, no un artefacto que se escribe una vez.
- Los umbrales son arbitrarios al inicio y se ajustan con datos reales.
