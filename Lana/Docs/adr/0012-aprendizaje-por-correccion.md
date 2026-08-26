# ADR-0012: Aprendizaje por corrección inyectado como vocabulario

- **Estado:** Aceptada
- **Fecha:** 2026-08-24

## Contexto

En el spike, la accuracy de categoría con frases genéricas llegó a 95%. Con las
frases reales del usuario —que incluían hiking, camping, clases de baile,
golosinas— cayó a 60-75%. Términos como "bocina", "acampar" y "chicles"
terminaban en `otro`.

Ningún prompt estático puede anticipar el vocabulario de una persona concreta.
Mejorar las definiciones ayuda hasta cierto punto, pero el techo lo pone que las
categorías las escribió alguien más.

## Decisión

Cuando el usuario corrige la categoría de un gasto, se guardan los **términos del
texto original** —no el concepto que generó el modelo— asociados a la categoría
que él eligió. Ese diccionario se inyecta al prompt de cada parseo.

Se guardan las palabras del usuario porque son las que va a volver a escribir.

**El vocabulario se inyecta como etiquetas, nunca como ejemplos con datos.** Una
línea `bocina → ocio, hiking → ocio` es segura. Un ejemplo tipo
`"gasolina 1010" → transporte` no lo es (ver ADR-0013).

Se conserva un número acotado de correcciones —las más recientes y las más
usadas— porque cada una alarga el prompt y la latencia importa en la pantalla
de captura.

## Consecuencias

- Medido en el spike: 75% → 90% de accuracy de categoría con 8 correcciones.
- **Se estabiliza, no crece indefinidamente.** El mecanismo resuelve vocabulario
  personal, no ambigüedad genuina. "Desayuno en el hiking" seguirá siendo
  ambiguo porque tiene dos señales legítimas en conflicto. No hay que
  interpretar el estancamiento como falla.
- Diagnóstico útil: si el vocabulario crece pero la accuracy no sube, el
  problema está en la definición de la categoría, no en el aprendizaje. Ahí se
  toca el `@Guide`.
- Es la única parte del sistema que mejora sola con el uso, y ataca
  directamente la razón por la que el usuario abandonó otros trackers.
