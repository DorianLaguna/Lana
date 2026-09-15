# ADR-0044: El sistema de diseño del rediseño "Hoy primero"

- **Estado:** Aceptada
- **Fecha:** 2026-09-15
- **Modifica:** ADR-0006 (pares curados) y ADR-0016 (superficie y texto por tema)

## Contexto

El rediseño aprobado (opción 1a "Hoy primero") llega como handoff de alta fidelidad
con valores exactos: tamaños de 15.5 y 12.5 pt, radios de 14/16/18/30, márgenes de
20, tinta con opacidades (`rgba(255,255,255,0.42)`), un solo acento por tema y
ningún rojo. El sistema anterior no podía expresarlo sin literales:

- `Space` solo tenía 4/8/16/24/32/48.
- `LanaTextStyle` eran cinco `Font.TextStyle` del sistema.
- Cada tema tenía un par primario/secundario y su propia superficie; la rampa de
  categorías pintaba doce colores que no significaban nada.
- `critical` (rojo) aparecía en errores y en botones de borrar.

La regla "ningún color ni espaciado literal en vistas" sigue vigente, así que el
sistema tenía que crecer hasta cubrir el diseño.

## Decisión

**Escala tipográfica por rol, escalada con Dynamic Type.** `LanaTextStyle` lista
roles (`heroAmount`, `rowTitle`, `sectionHeader`…) con el tamaño, peso e
interletraje del handoff. `lanaFont(_:)` los escala con `@ScaledMetric` relativo
al `Font.TextStyle` más cercano, y limita a XXL las cifras héroe. Las cifras
llevan `monospacedDigit` desde el estilo, no desde cada vista.

**Espaciado, radios y medidas con nombre.** `Space` agrega los pasos intermedios
que el diseño usa (2, 6, 7, 10, 12, 14, 18, 20…); `Radius` y `Layout` nombran
radios, márgenes de pantalla, alturas de componentes y el colchón del scroll.

**Superficie y tinta, una por modo, no por tema.** En oscuro se usan las del
handoff (`bg #0B0B0D`, `surface #15161A`, `surface2`, `surface3`, `ink #F5F6F8` y
tinta blanca con opacidad). Los cinco temas que siguen al sistema tienen un
análogo claro con las mismas opacidades recalculadas para dar el mismo contraste.
Esto revierte la parte de ADR-0016 que daba superficie propia a cada tema: la
jerarquía la da el fondo, y un fondo distinto por tema volvía a romperla.
Obsidiana, Ámbar y Zafiro siguen forzando oscuro.

**Un acento por tema, en tres formas.** `accentFill` es el hex de diseño (rellenos,
micrófono, swatch). `accent` es el mismo tono ajustado a 4.5:1 contra las
superficies del modo, para texto tocable. `onAccent` es blanco si da 3:1 sobre el
relleno y `bg` si no. Hace falta separarlos porque Zafiro `#1F4FA8` y Obsidiana
`#2A2C33` son rellenos correctos e ilegibles como texto sobre casi negro, y
Cempasúchil, Nopal y Ámbar no admiten texto blanco encima.

**Sin rojo y sin arcoíris.** `warning` y `critical` se fusionan en `attention`
(`#F08A4B`), que marca lo que reclama acción. Borrar es un swipe con el rojo del
sistema. Las categorías se dibujan en `ink28`, con la dominante en `attention`.
`highlight` queda solo como segundo tono de degradados decorativos.

**Contraste verificado por nivel.** `LanaThemeContrastTests` mezcla cada tinta con
opacidad sobre `bg`, `surface` y `surface2` antes de medir. `ink`, `ink70`–`ink50`
exigen 4.5:1; `ink45` e `ink42` exigen 3:1 (solo texto de apoyo ≥12.5 pt, regla del
handoff); `ink35` e inferiores son decorativos o de texto deshabilitado.

## Consecuencias

- El handoff se reproduce sin literales en las vistas.
- Elegir tema cambia el acento, ya no el fondo. Es menos "tema" en el sentido de
  ADR-0016, a cambio de una jerarquía que no cambia de pantalla a pantalla.
- `ink42` no llega a 4.5:1: nunca debe portar un dato único.
- Durante la migración conviven los estilos de transición (`largeAmount`, `body`…)
  y `categoryRamp` en gris; se eliminan cuando la última vista migra.
