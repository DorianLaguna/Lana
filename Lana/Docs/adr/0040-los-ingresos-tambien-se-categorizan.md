# ADR-0040: Los ingresos también se categorizan, con catálogo propio y solo a mano

- **Estado:** Aceptada
- **Fecha:** 2026-09-08
- **Revierte:** la regla de v1.0 de que solo los gastos se categorizan

## Contexto

Hasta ahora, en Lana un ingreso no tenía categoría. Estaba escrito en el modelo
(`Expense.category`: "`nil` para ingresos — solo los gastos se categorizan (v1.0)"), y el
formulario lo hacía cumplir: al cambiar el toggle a "Ingreso" desaparecían los pickers de
categoría y subcategoría, dejando solo concepto, monto y fecha.

El usuario fue a registrar dinero que ganó y buscó "salario". No estaba, y nunca estuvo:
las once categorías existentes (comida, despensa, transporte…) son todas de gasto.

La ausencia se volvió más visible con lo que se construyó los días previos. El disponible
proyectado (ADR-0039) se ancla al sueldo y el análisis del año desglosa a dónde se fue el
dinero, pero no de dónde vino. Un ingreso era un monto sin forma.

## Decisión

**Los ingresos se categorizan, con un catálogo propio de ocho** (`IncomeCategory`): sueldo,
freelance, venta, renta, inversión, reembolso, regalo, otro. Con subcategoría abierta
encima, igual que los gastos (ADR-0011).

Catálogo **aparte** de las once de gasto, no una ampliación: un solo picker donde "comida"
convive con "sueldo" no significa nada. Al voltear el toggle entre gasto e ingreso, la
categoría salta al catálogo que corresponde y la subcategoría se limpia — si no, se
guardaría un ingreso con categoría "comida", que su propio picker ni siquiera puede
mostrar.

**Las asigna la persona, no el parser.** El picker aparece en el `+`, en el editor y en el
formulario de recurrentes. Un ingreso dictado por voz entra sin categoría y se corrige
después. La razón es medible: el parser está en 68.3% de accuracy de categoría contra un
umbral de 80% (PLAN.md, Fase 3) — ya por debajo de su meta. Meterle un segundo catálogo
ahora arriesga arrastrar hacia abajo la clasificación de gastos, que es la que sostiene
todo lo demás. Por eso tampoco existe un `@Generable` espejo en `LanaParsing`.

**Un recurrente de ingreso también lleva categoría.** Así el sueldo puede decir que es
sueldo, y cada ocurrencia que se registre lo hereda. El método de pago sí sigue siendo solo
de gastos: un ingreso no se paga con nada.

**Se ve en dos lados:** un bloque "De dónde vino el dinero" en la vista anual, y una tool
determinista nueva (`origenDelIngreso`) para poder preguntarlo en lenguaje natural.

**El 50/30/20 no se toca.** El ingreso sigue siendo el denominador de la mezcla, nunca un
tramo (ADR-0037). Las categorías de ingreso jamás se etiquetan como Necesidad o Deseo.

### El cambio de esquema

`IncomeAdded` no tenía dónde guardar esto y gana `category` y `subcategory`. Los eventos
son inmutables y ya están guardados como JSON en `CDEvent.payload` (ADR-0005), así que
**los dos campos son opcionales**: los ingresos que ya existen no traen esas llaves y
decodifican como `nil`. No hace falta migrar nada ni tocar el modelo de Core Data. Hay una
suite que lo verifica generando el payload viejo desde el encoder real y decodificándolo.

Corregir la categoría de un ingreso no necesitó evento nuevo: `ExpenseCorrected` ya tenía
`category`.

## Consecuencias

- Lo que el usuario buscaba existe, y además le da forma al análisis: el año ahora dice de
  dónde vino el dinero, no solo a dónde se fue.
- **Un ingreso dictado por voz entra sin categoría.** Cae en "otro" en los desgloses hasta
  que alguien lo edite. Es el costo consciente de no tocar el parser mientras esté por
  debajo de su umbral.
- **Los ingresos ya registrados quedan todos en "otro".** No hay forma de adivinar
  retroactivamente cuál era sueldo y cuál no, y no se va a inventar: se corrigen a mano o
  se quedan así.
- Once categorías de gasto más ocho de ingreso son diecinueve, y la rampa de color tiene
  doce tonos: **entre catálogos hay choques inevitables**. No estorba porque se desglosan
  en bloques separados; lo que sí se garantiza es que dos categorías del mismo catálogo
  nunca compartan tono, y que "comida" y "sueldo" —las dos más frecuentes— salgan
  distintas.
- El desglose de ingresos no tiene drill-down. `CategoryDetailModel` filtra gastos por
  categoría, no ingresos, y pintar filas tocables prometería una pantalla que no existe.
- Las correcciones de categoría de un ingreso **no alimentan el vocabulario** del parser
  (ADR-0012). Inyectarle términos de ingreso a un prompt que solo clasifica gastos sería
  contaminarlo.
- El catálogo de ocho es más grande que el mínimo necesario. Si en uso real tres o cuatro
  quedan siempre vacías, quitarlas es un caso menos en el enum — pero los eventos ya
  guardados con esa categoría seguirían trayendo su string, así que conviene medir antes
  de podar.

## Qué haría reconsiderar esto

- Que el parser de gastos llegue a su umbral del 80%. Ahí sí vale la pena medir si
  clasificar ingresos automáticamente se sostiene, con casos propios en el golden set
  (ADR-0003).
- Que la mayoría de los ingresos terminen en "otro" pese al picker. Eso diría que el
  catálogo no calza con cómo entra el dinero de verdad, y la respuesta es cambiar la lista,
  no agregarle más casos.
