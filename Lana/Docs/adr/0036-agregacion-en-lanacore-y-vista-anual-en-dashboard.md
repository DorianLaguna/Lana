# ADR-0036: La agregación vive en `LanaCore`, y la vista anual dentro de `DashboardFeature`

- **Estado:** Aceptada
- **Fecha:** 2026-09-07

## Contexto

Lana solo sabía ver un mes. `DashboardModel` cargaba un `DateInterval` de un mes y
derivaba todo de ahí; no había forma de ver el año, comparar dos periodos ni construir
un solo insight narrado. Al abrir la vista anual aparecieron tres preguntas que había
que contestar antes de escribir una línea de UI.

**1. ¿Dónde vive la aritmética?** Estaba dentro de `DashboardModel` (`monthTotals`,
`categoryTotals`, `paymentMethodTotals`) y otra vez, en una segunda copia con reglas
distintas, en `CardsFeature/CardDetailModel.categoryTotals`. La vista anual habría sido
una tercera copia. Las features no pueden importarse entre sí
(Docs/ARCHITECTURE.md), así que "que el año importe el Dashboard" no era opción; y el
análisis con IA necesita exactamente las mismas cifras para poder narrarlas sin
calcularlas.

**2. ¿Dónde vive la pantalla del año?** Una quinta pestaña habría roto la geometría del
micrófono flotante: con cuatro tabs (número par) el overlay centrado cae solo en el
hueco entre la 2ª y la 3ª, sin geometría a mano.

**3. ¿En qué paquete van las llamadas al modelo?** `LanaCore` solo importa `Foundation`,
así que la implementación con `FoundationModels` tiene que vivir fuera.

## Decisión

**La aritmética de agregación vive en `LanaCore/Statistics/`**, como valores puros:
`PeriodStatistics` (totales, categorías, subcategorías, formas de pago y tasa de ahorro
de cualquier rango), `AnnualStatistics` (la serie de doce meses, extremos, promedio,
gastos hormiga y consistencia) y `PeriodComparison`. `MonthTotal` sube de
`DashboardFeature` a `LanaCore` renombrado a `PeriodTotal` — ya no es solo del mes.
`DashboardModel` y `CardDetailModel` pasan a delegar; ninguno conserva su propia copia.

Es el mismo precedente que ya habían sentado `DaySection` y `CategoryTotal`, que viven
en `LanaCore` justamente porque más de una feature los necesita.

**La vista anual vive dentro de `DashboardFeature`**, como un destino más de su
`NavigationStack` (`DashboardDestination.year`), a la que se entra por un botón en el
toolbar. No es tab nueva y no es paquete nuevo: reusa tal cual `CategoryBreakdownChart`,
`MonthSelector`, `CategoryDetailView` y `PaymentMethodDetailView`, que ya están ahí.

Para que los dos drill-downs sirvan igual al mes y al año sin duplicarse, se extrae el
protocolo interno `ExpenseProviding` (`expenses`, `viewerIdentities`, `calendar`), que
implementan `DashboardModel` y `YearModel`. `CategoryDetailModel` y
`PaymentMethodDetailModel` dejan de depender del `DashboardModel` concreto.

**La implementación con `FoundationModels` irá en un paquete nuevo, `LanaInsights`**,
hermano de `LanaParsing` y no una carpeta dentro de él: extraer datos de texto libre y
narrar cifras ya calculadas son dos responsabilidades distintas, y meterlas juntas
obligaría a `LanaParsing` a arrastrar el módulo de estadísticas que no usa.

## Consecuencias

- Toda la aritmética queda probada sin simulador, en la suite más rápida del repo. Las
  reglas que más fácil se rompen —no mezclar monedas, contar solo la parte propia de un
  gasto compartido— se prueban una vez y valen para las tres pantallas.
- `CardDetailModel.categoryTotals` cambió de implementación pero **no de semántica**: se
  construye a propósito sin `viewerIdentities`, que es justo lo que hace a
  `personalAmount` regresar el monto completo. Al banco se le debe el cargo entero sin
  importar cómo se reparta después entre personas — son ledgers separados
  (Docs/CLAUDE.md) y contar ahí la mitad diría que se debe menos de lo que va a llegar
  en el estado de cuenta. Queda documentado en el propio código porque es el error
  obvio que alguien "arreglaría" al pasar.
- `DashboardFeature` crece. Es el costo aceptado a cambio de no duplicar cuatro vistas.
  Si algún día el año necesita componentes que el mes no usa, la línea de corte natural
  es mover las gráficas compartidas a `LanaDesign` — pero eso hoy no se puede sin que
  `LanaDesign` gane una dependencia a `LanaCore` (recibe `[CategoryTotal]`, que es
  dominio), y esa dependencia sí rompería el grafo.
- La vista anual carga **veinticuatro meses** de una sola vez, no doce ni dos rangos: las
  comparaciones contra el mes anterior y contra el mismo mes del año pasado necesitan
  meses de fuera del año. No cuesta más que cargar un mes —
  `CoreDataExpenseStore.expenses(in:)` decodifica el log completo y filtra en memoria
  pase lo que pase. Ese detalle es el que hace barata la decisión; si algún día el store
  gana un filtro real por fecha, conviene revisitar el rango.
- El refresco central (ADR-0032) solo recarga el año **si el usuario ya lo abrió**
  (`YearModel.refreshIfLoaded()`). Sin esa guarda, cada gasto capturado pagaría una
  lectura de veinticuatro meses por una pantalla que nadie está viendo.

## Qué haría reconsiderar esto

- Que la vista anual y la mensual dejen de compartir componentes. Ahí `DashboardFeature`
  ya no estaría ahorrando duplicación y el año valdría su propio paquete.
- Que `ExpenseStore` gane consultas agregadas o un filtro por fecha a nivel de SQL. Eso
  cambiaría el cálculo de qué es barato cargar y probablemente movería parte de
  `Statistics/` a la capa de persistencia.
