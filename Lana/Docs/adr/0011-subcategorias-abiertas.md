# ADR-0011: Categorías cerradas, subcategorías abiertas y autogeneradas

- **Estado:** Aceptada
- **Fecha:** 2026-08-24

## Contexto

El spike de Fase 0.5 mostró que una sola dimensión de categoría no alcanza. Con
frases reales del usuario, `transporte` mezclaba traslados (uber, casetas,
estacionamiento) con gasto de vehículo (gasolina, refacciones, accesorios), y
`despensa` mezclaba la compra grande del súper con golosinas de tiendita. La
pregunta "¿cuánto me cuesta el carro?" era imposible de responder.

Las alternativas eran ampliar el enum de categorías, o introducir un segundo
nivel.

Ampliar el enum reintroduce el problema que el spike acababa de resolver: con la
taxonomía original la accuracy de categoría era 70%, y subió a 95% al reducir
ambigüedad, no al agregar opciones.

## Decisión

Dos niveles con reglas distintas:

- **Categoría: enum cerrado.** Nueve valores. El usuario no puede crear ni
  eliminar. Es lo que estructura presupuestos, gráficas y proyección.
- **Subcategoría: texto libre, propiedad del usuario.** El modelo propone un
  nombre; se resuelve por fuzzy match (Levenshtein) contra las que el usuario
  ya tiene en esa categoría, y si ninguna se parece lo suficiente, se crea y
  entra a su vocabulario.

La subcategoría **siempre es opcional** y nunca bloquea guardar.

El vocabulario acumulado se inyecta al prompt como lista de etiquetas por
categoría, para que el modelo reutilice nombres en vez de inventar variantes.

`otro` y variantes no son subcategorías válidas: si el modelo no puede
proponer algo específico, el campo queda vacío. Una subcategoría genérica no
aporta información y contamina el vocabulario de forma permanente.

## Consecuencias

- Se puede responder "cuánto me cuesta el carro" sin multiplicar categorías.
- La accuracy de categoría no se degrada, porque el enum sigue siendo chico y
  con fronteras nítidas.
- La subcategoría tendrá accuracy más baja que la categoría. Es aceptable: un
  error ahí no afecta presupuestos ni proyección. Se mide como métrica aparte.
- El fuzzy match necesita umbral calibrado por longitud. Sin él, "gasolina" y
  "gasolinas" se vuelven dos subcategorías distintas y el vocabulario se ensucia.
- Si el usuario quiere una categoría que no existe (regalos, por ejemplo), no
  puede crearla. Esa restricción se revisa con un ADR nuevo, no relajando la
  regla.
