# ADR-0038: El catálogo de tools deterministas, y qué queda fuera de él

- **Estado:** Aceptada, parcialmente revisada por ADR-0039
- **Fecha:** 2026-09-07

## Contexto

La Fase 9 del plan pedía seis tools para las preguntas en lenguaje natural:
`totalPorCategoria`, `comparaMeses`, `mayoresGastos`, `saldoDeLista`,
`disponibleProyectado` y `deudaPorTarjeta`. Al implementarlas salieron dos cosas.

**Una es que `disponibleProyectado` no se puede calcular.** `Projection.available(...)`
recibe un `currentBalance` — el dinero real que hay en la cuenta — y Lana no lo tiene en
ningún lado: no hay saldo bancario, no hay conexión a la cuenta, y el único sitio donde
ese parámetro aparece con un valor es en los tests. Sin él, la tool tendría que inventar
una base, y un disponible inventado es la peor cifra posible en una app de dinero.

**La otra es cómo el modelo dice "este mes".** Las herramientas necesitan un mes concreto.
Que el modelo lo calcule contradice la regla de que el modelo no calcula; y meter la fecha
de hoy en las instructions contradice ADR-0013, porque la fecha es dato.

## Decisión

**Se implementan cinco tools, no seis.** `disponibleProyectado` queda fuera hasta que
exista una fuente de saldo real.

`LedgerToolbox.catalog` nombra exactamente las que sí existen, y las preguntas sugeridas
de la UI salen de ese catálogo — no se le sugiere al usuario nada que después no se pueda
contestar.

> **Revisado el mismo día por ADR-0039.** El saldo no tenía que venir del banco: se deriva
> de lo que el usuario registró desde su último sueldo, anclando el periodo a un
> `RecurringItem` de ingreso. `disponibleProyectado` existe y las tools son seis. El resto
> de este ADR sigue vigente tal cual.

**Toda la aritmética vive en `LedgerToolbox`, en `LanaCore`**, y cada método devuelve
**texto ya formateado**, no números. Es la misma frontera que `PeriodFacts`: si el modelo
recibiera un `Decimal`, alguien terminaría pidiéndole que lo opere. `LanaInsights` solo
aporta el envoltorio `Tool` con su esquema de argumentos.

**La fecha de hoy y el periodo en pantalla viajan en el prompt**, no en las instructions
(ADR-0013), y el modelo los lee para resolver "este mes" o "el mes pasado" a un año y un
mes concretos. Leer una fecha que se le dio no es calcularla.

> **Corregido el 2026-09-08.** Al principio solo viajaba la fecha de hoy, y eso producía un
> bug real: estando en agosto, preguntar "¿cuáles fueron mis gastos más grandes?"
> contestaba sobre septiembre. La pregunta no nombra el mes justamente porque la persona ya
> lo está viendo, así que el periodo en pantalla (`QueryPeriod`) también es dato que hay que
> darle. Los argumentos se validan en el toolbox: un mes fuera de
1-12 devuelve "Ese mes no existe" en vez de un rango inventado, y el número de resultados
se acota aunque el modelo pida novecientos.

**Las dos deudas siguen separadas.** `saldoDeLista` (entre personas) y `deudaPorTarjeta`
(con el banco) son tools distintas, y tanto sus descripciones como las instrucciones de la
sesión dicen explícitamente que no se suman (Docs/CLAUDE.md).

`InsightQuerying` pierde el parámetro `tools:` que traía desde la Fase 1. Quien implementa
el protocolo arma su propio `LedgerToolbox` con los stores inyectados, igual que
`FoundationModelsExpenseParsing` sostiene los suyos.

## Consecuencias

- Las cinco tools se prueban sin simulador y sin Apple Intelligence: son funciones puras
  sobre stores en memoria. Si una devuelve mal un número, la respuesta sale mal, así que
  ahí es donde están los tests.
- ~~**La app no puede contestar "¿cuánto me queda para la quincena?"**~~ — resuelto el
  mismo día por ADR-0039, sin saldo inicial ni integración bancaria.
- Devolver texto y no números hace las tools más difíciles de recomponer entre sí: el
  modelo no puede tomar dos resultados y combinarlos. Es a propósito. Si hace falta una
  cifra combinada, se agrega una tool que la calcule, no se le pide al modelo que sume.
- El modelo puede elegir mal la herramienta o el mes. Eso produce una respuesta poco útil,
  no una respuesta incorrecta: la cifra que narra siempre es una cifra real de un periodo
  real.
- Cinco tools con sus `@Generable` de argumentos son cinco esquemas que el modelo lee en
  cada sesión. Si el catálogo crece mucho, hay que medir si la elección se degrada.

## Qué haría reconsiderar esto

- Que el modelo se equivoque seguido eligiendo el mes. La salida sería un extractor
  determinista de periodo sobre el texto de la pregunta, como `RelativeDateExtractor` hace
  para el parser — no darle más libertad al modelo.
