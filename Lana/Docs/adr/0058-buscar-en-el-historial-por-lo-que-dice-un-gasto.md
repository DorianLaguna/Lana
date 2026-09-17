# ADR-0058: Buscar en el historial por lo que dice un gasto

- **Estado:** Aceptada
- **Fecha:** 2026-09-17
- **Relacionada:** ADR-0038 (catálogo de tools deterministas), ADR-0013 (sin datos
  en instrucciones), ADR-0018 y ADR-0057 (Siri fuera de v1.0)

## Contexto

El usuario preguntó si podía decirle a Siri "pregúntale a Lana cuándo fue la última
vez que compré gasolina". Al revisarlo salieron dos cosas separadas.

**La de Siri** se decidió por ahora que no: sigue fuera de v1.0 (ADR-0018,
ADR-0057). Además Siri no puede capturar texto libre dentro de la frase de
invocación —solo parámetros de un catálogo cerrado (`AppEnum`/`AppEntity`)—, así
que la forma natural de esa pregunta no es una frase, sino "pregúntale a Lana" y
después hablar.

**La otra es que esa pregunta tampoco se podía contestar dentro de la app.** Las
herramientas existentes contestan sobre **un mes** dado: totales por categoría,
comparar dos meses, los gastos más grandes, de dónde vino el ingreso, saldo de una
lista, deuda por tarjeta, disponible. "¿Cuándo fue la última vez que compré
gasolina?" es justamente no saber en qué mes buscar, y el modelo no puede buscarlo
por su cuenta: no ve el historial, y esa es la regla que hace que nunca invente una
cifra (Docs/CLAUDE.md).

## Decisión

**Una herramienta más: `buscarPorConcepto(texto:)`**, séptima del catálogo.

- Busca en **todo el historial** (diez años hacia atrás; `ExpenseStore` pide un
  rango y no existe "todo"), no en un mes.
- Empareja contra **concepto, categoría y subcategoría**, sin acentos ni
  mayúsculas — el mismo `normalize` que ya usa el emparejamiento de listas.
- Contesta tres cosas: cuándo fue el último y de cuánto, cuántos van y cuánto
  suman, y desde cuándo. Con eso cubre "¿cuándo fue la última vez…?", "¿cada cuánto
  pago…?" y "¿cuánto llevo gastado en…?" sin tres herramientas distintas.
- **Una línea por moneda.** Nunca se suman entre sí (Docs/CONVENTIONS.md).
- Con menos de dos letras no busca: pide más detalle, en vez de traer el historial
  entero.
- Devuelve texto ya formateado, como el resto del toolbox: el modelo narra, no
  calcula.

**No hay chip de un toque para esto.** Los chips (`QuickAnswer`) son preguntas sin
parámetro; esta necesita que la persona diga qué busca, así que vive en la pregunta
escrita o dictada del Análisis.

## Consecuencias

- Se pueden contestar preguntas que no nombran un mes, que eran un hueco entero del
  catálogo.
- **Busca por texto, no por significado.** "Gasolina" no encuentra "Pemex" si el
  gasto nunca dijo gasolina y su categoría es "transporte". La subcategoría ayuda,
  pero quien capture con nombres distintos para lo mismo verá menos de lo que
  espera.
- Leer diez años de movimientos por cada pregunta es más caro que leer un mes. Hoy
  el historial cabe de sobra en memoria; con años de uso, esto es lo primero que
  habría que acotar.
- El modelo ahora tiene siete herramientas para elegir, y elegir mal es más
  probable con más opciones. La descripción dice explícitamente cuándo usarla
  ("sin importar el mes").

## Qué haría reconsiderar esto

- Que la búsqueda por texto se quede corta seguido. La salida sería indexar
  concepto y subcategoría por parecido (fuzzy), como ya hace el vocabulario de
  correcciones, no darle el historial al modelo.
