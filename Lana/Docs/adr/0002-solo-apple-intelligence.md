# ADR-0002: Requerir Apple Intelligence, sin parser de respaldo

- **Estado:** Aceptada — **validada empíricamente 2026-08-24**
- **Fecha:** 2026-08-23

## Contexto

El producto se sostiene sobre convertir texto libre en español mexicano a un
gasto estructurado. Hay tres formas de lograrlo on-device:

1. Reglas: regex de montos + diccionario de categorías con fuzzy matching.
2. Modelo chico embebido: clasificador entrenado localmente o embeddings en ONNX.
3. El modelo del sistema vía `FoundationModels`.

La opción 3 es gratuita, no suma peso a la app, y con `@Generable` garantiza que
la salida cumple el tipo esperado — cosa que un modelo de 0.5-1B empaquetado no
garantiza.

Su costo es de alcance: existe solo en devices con Apple Intelligence, que es un
subconjunto de los que corren iOS 26.

Mantener las tres capas en cascada daría cobertura total, pero implica construir
y mantener el diccionario español-MX completo y una segunda ruta de parseo —
trabajo comparable al del producto entero.

## Decisión

La app requiere Apple Intelligence. No se implementa parser de respaldo por reglas.

En devices sin soporte, la app muestra una pantalla explicativa y no permite el
flujo de captura.

Se conserva **una** pieza del enfoque por reglas: `AmountValidator`, un extractor
de montos por regex. No es un fallback de cobertura sino de correctitud — el
modelo del sistema ocasionalmente equivoca el monto, y en una app de finanzas ese
error es inaceptable. El regex corre siempre y su resultado tiene prioridad.

## Consecuencias

- El mercado direccionable se reduce notablemente, sobre todo en México, donde la
  penetración de iPhone reciente es baja. Es una decisión de producto asumida:
  esto es un proyecto propio, no un negocio con metas de volumen.
- El desarrollo se acelera de forma significativa.
- La app queda expuesta a cambios en el modelo del sistema entre versiones de iOS.
  Se mitiga con el golden set en CI (ver ADR-0003).
- Si más adelante el alcance importa, agregar la capa de reglas es aditivo: se
  implementa `ExpenseParsing` una segunda vez y se resuelve por `availability`.
  La arquitectura ya lo permite sin refactor.


## Validación empírica (spike de Fase 0.5, 2026-08-24)

Se probó el modelo del sistema contra 20 frases reales del usuario en español
mexicano coloquial, en iPhone físico con iOS 26.

| Métrica | Resultado |
|---|---|
| Conteo de gastos por frase | 100% |
| Monto | 100% |
| Categoría (prompt base) | 60-75% |
| Categoría (con aprendizaje por corrección) | 90% |

El modelo interpretó correctamente jerga mexicana ("varos", "chescos", "la
bodega", "mil quinientos"), montos escritos con palabras, y autocorrección del
usuario a media frase ("1000 ah ah no 131").

Se confirmó también la necesidad del `AmountValidator`: el modelo devolvió 45000
donde el texto decía 45, y sumó dos gastos en uno (300 + 460 = 760) cuando el
esquema solo permitía un elemento. Ambos errores fueron detectados por
comparación con regex sobre el texto crudo. En una app de finanzas, cualquiera
de los dos habría corrompido datos en silencio.

La decisión se mantiene sin cambios.
