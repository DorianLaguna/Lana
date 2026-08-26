# ADR-0013: Nunca poner datos concretos en las instrucciones del parser

- **Estado:** Aceptada
- **Fecha:** 2026-08-24

## Contexto

Durante el spike, una instrucción incluía un ejemplo con cifras:

> "compré 300 del súper e igual fui al cine y fueron 460" son dos gastos: uno de
> 300 en despensa y otro de 460 en ocio.

El modelo empezó a devolver un gasto de **460 en ocio** en respuestas a frases
que no lo mencionaban: "300 de súper", "unos tacos 85 varos", "1,250.50 de la
luz". La accuracy de conteo cayó a 13%.

El ejemplo del prompt se estaba filtrando a la salida como si fuera dato del
usuario.

## Decisión

Las instrucciones del parser **no contienen cifras, montos ni frases completas
de ejemplo**. Solo reglas abstractas y listas de etiquetas.

Las instrucciones incluyen una línea explícita indicando que no contienen datos
del usuario y que nada de ahí debe copiarse a la respuesta.

La distinción operativa: una lista de nombres de categoría o subcategoría es
**vocabulario de salida** y es segura. Un ejemplo con un monto es **dato** y no
lo es.

## Consecuencias

- Los ejemplos few-shot con datos quedan prohibidos en cualquier extractor del
  proyecto. Si en algún momento parecen necesarios, hay que medir la
  contaminación antes de aceptarlos.
- El aprendizaje por corrección (ADR-0012) es compatible porque inyecta pares
  `término → categoría`, sin montos.
- La suite del golden set detecta este tipo de regresión: una cifra que aparece
  en respuestas de casos que no la contienen es la firma inconfundible.
