# ADR-0037: La regla de presupuesto la elige el usuario, y el modelo etiqueta sin ver montos

- **Estado:** Aceptada
- **Fecha:** 2026-09-07

## Contexto

El análisis con IA arrancó como "clasificación 50/30/20": la IA etiqueta cada gasto como
Necesidad, Deseo o Ahorro, el código suma y compara contra 50/30/20. Al revisarlo salieron
dos problemas distintos.

**El primero es de producto.** 50/30/20 es la regla más conocida, no la única ni la
correcta para todos. Con un ingreso justo, el 50% de necesidades es inalcanzable: la barra
viviría permanentemente en falta contra una meta que nunca dio. Eso es exactamente el tono
que el proyecto prohíbe — "Lana no regaña" (Docs/CLAUDE.md). Y cuál regla seguir es una
decisión personal, no una constante que le toque fijar al código.

**El segundo es de arquitectura.** La regla del proyecto dice que el modelo no calcula,
solo narra. Pero "etiquetar cada gasto" en el sentido literal significa pasarle
transacciones — con sus montos — y confiar en que no sume. Confiar no es una garantía.

También quedó pendiente qué mostrar cuando no hay ingreso registrado: la regla se mide
sobre el ingreso, y sin denominador no hay porcentaje que comparar.

## Decisión

**La regla de presupuesto es una preferencia del usuario.** Se ofrecen cuatro
(`BudgetRule`): 50/30/20, 70/20/10, 60/20/20 y "Págate primero" (20% al ahorro y el 80%
restante sin dividir). Se elige desde la propia pantalla de Análisis, no desde Ajustes, y
se guarda en `UserDefaults` — es una preferencia, no un derivado, así que persistirla no
contradice ADR-0005.

El estado inicial es **sin regla**, y es un estado de primera clase: se muestra la mezcla
real sin metas. Ponerle una meta que no pidió es justo lo que esta app no hace. Cuando hay
material suficiente, Lana **sugiere** una del catálogo, con un botón para adoptarla y un
descarte que se recuerda.

Las cuatro reglas se miden sobre el ingreso y usan los mismos tres grupos, así que
**cambiar de regla solo cambia las metas**: no reclasifica nada ni vuelve a llamar al
modelo. Eso es lo que hace barato dejarlo en manos del usuario.

**El modelo clasifica vocabulario, no transacciones.** `SpendingClassifying` recibe los
pares distintos `categoría / subcategoría` del periodo (`"comida / café"`, `"hogar /
renta"`) y devuelve una etiqueta por par. No recibe montos, ni fechas, ni conceptos: no
puede sumar aunque quisiera. Las sumas las hace `BudgetMix`, en `LanaCore`. Como el
vocabulario son decenas de pares al año y no cientos de movimientos, una sola llamada
cubre el periodo completo.

**Las etiquetas no se persisten.** Se cachean en memoria mientras vive el proceso y se
recalculan al reabrir la app.

**El ahorro se define como lo que sobró:** `ingreso − necesidades − deseos − sin
clasificar`. Así entra a la misma cifra tanto el dinero apartado a propósito (un gasto
etiquetado como ahorro) como el que simplemente no se gastó, sin contar nada dos veces, y
los cuatro montos suman el ingreso exacto. Puede salir negativo, y se muestra negativo.

**Sin ingreso registrado**, los porcentajes se miden contra el gasto, no hay metas y no
aparece el tramo de ahorro — no se sabe qué sobró. Mismo criterio que la dona del
Dashboard, que solo aparece con ingreso.

**Dos guardas deterministas**, en el espíritu de `ParsingPipeline` (el código corrige al
modelo, no al revés):

- La regla que el modelo recomiende se valida contra `BudgetRule.allCases`. Fuera del
  catálogo, la recomendación se descarta en silencio.
- Un par que vuelva sin etiqueta va a `unclassified` y se reporta aparte. **Nunca se
  reparte** entre los tres grupos: eso movería un porcentaje sin que el usuario hubiera
  gastado nada.

Para narrar (`InsightNarrating`), el modelo recibe `PeriodFacts`: las cifras **ya
calculadas y ya formateadas a texto**. Todo llega como `String` a propósito — un `Decimal`
invitaría a pedirle "sácame el porcentaje". Las cifras viajan en el prompt, nunca en las
instructions (ADR-0013).

Todo esto vive en `LanaInsights`, paquete nuevo (ADR-0036).

## Consecuencias

- La garantía de que el modelo no calcula deja de ser confianza y pasa a ser estructural:
  no tiene los números. Hay tests que verifican que la etiqueta enviada no contiene
  dígitos, que las instrucciones no traen una sola cifra, y que cambiar de regla no mueve
  los porcentajes reales.
- **No guardar las etiquetas cuesta:** cada apertura de la pantalla espera al modelo
  (~1-3 s) y la misma subcategoría podría caer en un grupo distinto entre aperturas, así
  que los porcentajes pueden moverse sin que el usuario gastara nada. Se acepta a cambio
  de no tocar el esquema de Core Data ni sincronizar por CloudKit una tabla de etiquetas.
  Si el parpadeo molesta en uso real, la respuesta es un store propio —hermano de
  `CorrectionVocabularyStore`— y no un default silencioso.
- **El usuario no puede corregir una etiqueta.** Si la IA pone "gimnasio" en Deseo y él lo
  considera Necesidad, no hay dónde cambiarlo. Es consecuencia directa de no persistir:
  una corrección que se olvida al cerrar la app sería peor que no tenerla.
- Clasificar por vocabulario y no por transacción tiene un límite real: **el mismo par
  categoría/subcategoría siempre cae en el mismo grupo.** Una cena de trabajo y una cena
  de antojo, ambas "comida / restaurante", comparten etiqueta. Es el precio de que el
  modelo no vea montos ni conceptos, y se consideró mejor que la alternativa.
- El análisis se hace sobre **una sola moneda**, la de más gasto, y la pantalla dice
  cuáles quedaron fuera. Cruzarlas está prohibido y una narrativa por moneda serían N
  llamadas al modelo.
- Cuatro reglas es un catálogo cerrado que alguien va a querer ampliar. Agregar una es un
  caso más del enum y sus metas; no toca la clasificación ni la aritmética.

## Qué haría reconsiderar esto

- Que el usuario pida corregir etiquetas. Eso obliga a persistirlas, y con la persistencia
  llega naturalmente la UI de override.
- Que la clasificación por vocabulario resulte demasiado gruesa en uso real — que la misma
  subcategoría claramente signifique dos cosas distintas seguido. La salida no es darle
  montos al modelo: es partir la subcategoría, o dejar que el usuario decida.
- Que la mayoría termine usando la misma regla. Ahí el catálogo sobra y bastaría con esa,
  más la opción de no tener ninguna.
