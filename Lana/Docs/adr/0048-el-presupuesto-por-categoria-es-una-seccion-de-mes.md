# ADR-0048: El presupuesto por categoría es una sección de Mes, no un paquete

- **Estado:** Aceptada
- **Fecha:** 2026-09-16
- **Relacionada:** ADR-0036 (agregación en `LanaCore`, vista anual en Dashboard),
  ADR-0037 (la regla de presupuesto es del usuario), ADR-0044 (rediseño)

## Contexto

`BudgetsFeature` existía desde el scaffold de Fase 0: un `enum` con el nombre del
módulo y un test que lo verificaba. Nunca tuvo vista ni modelo, pero la app lo
enlazaba y `Docs/ARCHITECTURE.md` lo dibujaba como una de las features de primer
nivel. Quien leía el grafo buscaba una pantalla de presupuestos que no existe.

Mientras tanto aparecieron dos cosas con "presupuesto" en el nombre, y ninguna
cayó ahí:

1. **La regla 50/30/20 y sus variantes** (ADR-0037) es una sección del Análisis:
   `BudgetMixSection` en `InsightsFeature`, con la aritmética en `LanaCore`
   (`BudgetMix`).
2. **El presupuesto mensual por categoría** —la Fase 7 de `PLAN.md`, dentro de
   v1.0— sigue sin hacerse.

Se consideraron tres salidas:

- **Llenar `BudgetsFeature`** con la Fase 7. Es lo que el scaffold anticipaba. Pero
  el rediseño (ADR-0044) no tiene pestaña de presupuestos: son cuatro pestañas y
  lo que no responde "¿cuánto me queda?" baja a Mes. Un avance por categoría se
  lee junto a "En qué se fue", y las features no se importan entre sí, así que
  desde un paquete aparte Mes no podría mostrarlo sin subir todo a la app o
  duplicar vistas.
- **Mover también la mezcla 50/30/20 a `BudgetsFeature`**, para juntar todo lo
  que se llama presupuesto. Obliga a bajar los tipos compartidos a `LanaCore` y a
  que el Análisis dependa de otra feature por medio de la app. Más trabajo para
  agrupar por nombre dos cosas que se usan en pantallas distintas.
- **Borrar el paquete** y decidir dónde vivirá la Fase 7 cuando se haga.

## Decisión

**Se borra `BudgetsFeature`**: el paquete, su enlace en el proyecto de Xcode y su
nodo en el grafo de `Docs/ARCHITECTURE.md`.

**El presupuesto por categoría sigue en v1.0 y vivirá en `DashboardFeature`**,
como sección de Mes, igual que la vista anual (ADR-0036). La cuenta —cuánto va
contra cuánto se fijó— va en `LanaCore`, junto a `PeriodStatistics`; la feature
solo la dibuja.

**Un paquete existe cuando tiene una pantalla o una implementación propia**, no
por adelantado. Queda como regla en `Docs/ARCHITECTURE.md`.

## Consecuencias

- El grafo documentado vuelve a corresponder a los paquetes que existen. De paso
  se corrigieron dos errores que ya tenía: faltaba `OnboardingFeature` y
  dibujaba a `LanaDesign` dependiendo de `LanaCore`, que ADR-0047 descarta.
- **`DashboardFeature` crece.** Ya tiene Hoy, Mes, el año, los drill-downs y los
  recurrentes. Sumar presupuestos lo vuelve el paquete más grande de la app, y
  compilarlo y probarlo tarda más.
- Si un día los presupuestos necesitan pantalla propia (editar metas, historial
  de cumplimiento, alertas), la separación hay que volver a hacerla, esta vez
  con código real que mover y no con un scaffold vacío.
- "Presupuesto" sigue nombrando dos cosas en lugares distintos: la mezcla por
  grupos en Análisis y el tope por categoría en Mes. El copy de cada pantalla
  tiene que distinguirlas.

## Qué haría reconsiderar esto

- Que el presupuesto por categoría termine con flujos propios que no caben en
  una sección de Mes: una hoja de edición con varias pantallas, o notificaciones.
- Que `DashboardFeature` se vuelva lento de compilar o de probar al punto de
  estorbar. Ahí conviene partir el paquete por pantalla, no por palabra.
