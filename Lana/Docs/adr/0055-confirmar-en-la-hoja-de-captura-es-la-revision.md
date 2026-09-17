# ADR-0055: Confirmar en la hoja de captura ya es la revisión

- **Estado:** Aceptada
- **Fecha:** 2026-09-17
- **Relacionada:** ADR-0009 (Apple Pay entra por revisar), ADR-0025 (detección de
  gasto compartido en captura general), ADR-0043 (voz con preview en vivo)

## Contexto

Un movimiento dictado podía terminar marcado "por revisar" aunque la persona lo
acabara de ver y confirmar. Pasaba cuando el parseo en vivo no había alcanzado a
correr sobre todo lo dictado: al parar el micrófono se parsea la frase completa, y
ahí el modelo marca `needsReview` si algo le pareció ambiguo (o el monto lo corrigió
el regex, `AmountValidator`). Con el mismo dictado, esperar a que el preview
apareciera dejaba el movimiento limpio y no esperar lo dejaba marcado —dos
resultados distintos para lo mismo, como lo reportó el usuario.

El fondo es que `needsReview` se estaba usando para dos cosas distintas:

- **Lo que entró solo** —Apple Pay (ADR-0009), tickets (ADR-0010)— y nadie ha
  mirado. Para eso existe la bandeja "Por revisar" de Hoy.
- **Lo que el parser no tuvo claro** en una captura que la persona **sí** está
  mirando, con sus chips de duda, antes de tocar Guardar.

Marcar lo segundo manda a la bandeja algo que ya se revisó, y la bandeja pierde su
significado: deja de ser "esto entró sin que lo vieras".

## Decisión

**Confirmar en la hoja de captura es la revisión.** Al guardar desde ahí, el
movimiento entra sin marca (`DraftTransaction.confirmed()`).

**Salvo que le falte un dato concreto**: sin monto, sin concepto, o un gasto sin
categoría. Eso no es una duda del modelo, es un hueco real, y guardar nunca se
bloquea (Docs/CLAUDE.md), así que el movimiento entra y la bandeja lo recuerda.

La duda genérica del parser —el chip "Revisa que esté bien"— se sigue mostrando
**mientras** se revisa; lo que deja de hacer es sobrevivir a la confirmación.

Un gasto compartido detectado por el texto también se guarda sin marca: ADR-0025 lo
forzaba a `needsReview` para que la persona confirmara el match, y ahora lo confirma
viendo el bloque "Compartido en …" en la misma hoja, con "Quitar" al lado.

La bandeja "Por revisar" sigue limpiando la marca al confirmar, como antes: ahí la
persona está justamente revisando.

## Consecuencias

- Dictar y guardar ya no deja trabajo pendiente inventado, y el punto de Hoy vuelve
  a significar "entró algo solo".
- **Una corrección del regex sobre el monto deja de ser visible después de
  guardar.** Se ve como chip mientras se revisa; si la persona no le hace caso ahí,
  nadie se lo va a recordar. Es el precio de que la bandeja signifique una sola cosa.
- Un gasto dictado sin categoría sigue yendo a la bandeja. Es el caso más común de
  marca que queda, y es un hueco de verdad.

## Qué haría reconsiderar esto

- Que empiecen a guardarse montos mal corregidos por el regex sin que nadie lo note.
  La salida sería que ese caso muestre el monto original al lado en la hoja, no que
  vuelva a la bandeja.
