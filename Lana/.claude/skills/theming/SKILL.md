---
name: theming
description: El sistema de diseño y temas de color de Lana — tokens semánticos, los ocho temas curados, la escala tipográfica y de espaciado, los componentes base y las reglas para usarlos. Usa esta skill siempre que se escriba o modifique cualquier vista de SwiftUI, se elija un color, se toque LanaDesign, o se trabaje en la pantalla de personalización de tema. Aplica aunque el usuario no mencione diseño ni colores.
---

# Sistema de diseño de Lana

La fuente de verdad es ADR-0044 (rediseño "Hoy primero"). Esto es el resumen
operativo.

## Los tres principios del rediseño

1. **Una pantalla, una pregunta.** Arriba se responde lo importante; el desglose
   se pide, no se impone.
2. **Dictar es la app.** El micrófono vive dentro de la barra de pestañas y nunca
   tapa contenido.
3. **Un solo acento.** Sin arcoíris: gris con un acento para lo que domina.

## Temas

El usuario elige uno de **ocho temas curados**, nunca colores sueltos. Desde
ADR-0044 un tema cambia **solo el acento**; superficies y tinta son las mismas
para todos (en oscuro las del handoff, en claro su análogo). Obsidiana, Ámbar y
Zafiro fuerzan oscuro; los otros cinco siguen al sistema.

| Tema | Relleno (`accentFill`) |
|---|---|
| Cobalto *(default)* | `#5B7CFA` |
| Cempasúchil | `#F08A4B` |
| Jacaranda | `#8A6CF0` |
| Nopal | `#4FD08A` |
| Bugambilia | `#D8578F` |
| Obsidiana | `#2A2C33` |
| Ámbar | `#C9962E` |
| Zafiro | `#1F4FA8` |

El acento existe en tres formas:

- `accentFill` — rellenos: botones, barras, micrófono, swatch.
- `accent` — **texto** tocable. Mismo tono ajustado a 4.5:1 por modo.
- `onAccent` — lo que va encima de `accentFill` (blanco o `bg`).

Nunca uses `accentFill` como color de texto: en Zafiro y Obsidiana no se lee.

## Tokens de color

```swift
// Superficies
lana.bg          // fondo de pantalla
lana.surface     // tarjetas
lana.surface2    // chips, pistas de barras, botón secundario
lana.surface3    // segmento activo, avatar sobre tarjeta
lana.hairline / lana.hairlineStrong

// Tinta
lana.ink         // texto principal y cifras
lana.ink70 … lana.ink28   // apoyo con opacidad; ink42 solo para apoyo ≥12.5 pt

// Semánticos (fijos en todos los temas)
lana.attention   // por revisar, pendientes, lo que domina
lana.positive    // ingresos, saldos a favor
```

- **No hay rojo.** Ni para gastos ni para borrar. Borrar es un swipe o
  `role: .destructive`: el rojo lo pone el sistema durante el gesto.
- **Un acento por pantalla.** `attention` marca lo que reclama acción; `accent`
  lo que se puede tocar. Nunca compitiendo en el mismo bloque.
- **Las categorías no tienen color.** Barras en el acento, la dominante en
  `attention` (`RankedBarList` ya lo hace).
- Los fondos teñidos tienen token: `attentionSoft`, `attentionChip`,
  `accentSoft`, etc. No escribas `.opacity(0.13)` en una vista.

## Tipografía

`lanaFont(_:)` con un rol de `LanaTextStyle`: `heroAmount`, `screenAmount`,
`rowTitle`, `rowSubtitle`, `sectionHeader`, `explanation`… Tamaños del handoff,
escalados con Dynamic Type; las cifras llevan dígitos tabulares desde el estilo y
las héroe se limitan a XXL. Los estilos de transición (`largeAmount`, `body`,
`caption`…) desaparecen cuando migre la última vista.

## Espaciado, radios y medidas

- `Space`: `xs/sm/md/lg/xl/xxl` (4/8/16/24/32/48) y los intermedios por valor
  (`p10`, `p13`, `p18`…).
- `Radius`: `inner` 14, `card` 16, `cardLarge` 18, `sheet` 28, `tabBar` 30.
  Píldoras y avatares: `Capsule()` / `Circle()`.
- `LanaMetrics`: `screenMargin` 20, alturas de componentes, grosores de barra.
- Toda pantalla con barra de pestañas termina su scroll con
  `.tabBarClearance()` (`.today` en Hoy).

Un `.padding(17)` o un `Color(red:…)` en una feature es un bug: si falta un
valor, falta un token.

## Componentes base

`LanaCard`, `SectionHeader`, `MovementRow`, `HairlineDivider`, `NavRow`,
`ProgressTrack`, `RankedBarList`, `Chip`, `FlowLayout`, `.buttonStyle(.lana(...))`,
`InitialAvatar`, `EmptyStateView`, `MonthSelector`, `YearSelector`,
`LanaDateFormat` (fechas siempre en español). Úsalos antes de dibujar a mano.

## Reglas al escribir vistas

- Ningún color, espaciado, radio ni tamaño literal fuera de `LanaDesign`.
- Ninguna tarjeta lleva sombra: la jerarquía la da el fondo.
- Toda vista pública con `#Preview` que itera `LanaTheme.allCases`.
- El color nunca es el único portador de información: los ingresos llevan `+`,
  lo pendiente lleva texto o ícono.
- Área de toque mínima 44 pt; filas de 48 pt o más.
- Todo icono lleva etiqueta de accesibilidad.

## Tono

Lana no regaña. Un exceso es un dato con la acción al lado. En copy: "Podrías…",
"Si quieres…"; nunca "deberías", "cuidado" ni signos de admiración. En color:
`attention` donde hay algo que hacer, nunca para juzgar.
