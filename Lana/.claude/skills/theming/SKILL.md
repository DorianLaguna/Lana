---
name: theming
description: El sistema de diseño y temas de color de Lana — tokens semánticos, los seis pares de color curados, y las reglas para usarlos. Usa esta skill siempre que se escriba o modifique cualquier vista de SwiftUI, se elija un color, se toque LanaDesign, o se trabaje en la pantalla de personalización de tema. Aplica aunque el usuario no mencione diseño ni colores.
---

# Sistema de diseño de Lana

## Principio

El usuario personaliza el tema **eligiendo un par curado**, nunca colores sueltos.

La razón es concreta: dos colores escogidos al azar se pelean, rompen contraste y
hacen que la app se vea rota. Con pares diseñados, cualquier combinación que el
usuario elija se ve bien y cumple accesibilidad. Él siente que la app es suya; tú
conservas el control de que se vea bien.

Un color picker libre es más "poder" para el usuario y peor producto.

## Tokens semánticos

Los colores se nombran por su **rol**, nunca por cómo se ven. `Color.lana.accent`,
jamás `Color.lana.blue`. Cuando el usuario cambia de tema, el rol sigue siendo
correcto y el nombre sigue teniendo sentido.

```swift
public extension ShapeStyle where Self == Color {
    static var lana: LanaColors { LanaColors() }
}

public struct LanaColors {
    // Derivados del tema
    public let accent: Color          // primario: acciones, selección, foco
    public let accentMuted: Color     // primario al 15%: fondos de estado activo
    public let highlight: Color       // secundario: datos, gráficas, categorías
    public let categoryRamp: [Color]  // 8 tonos derivados del par, en orden fijo

    // Fijos en todos los temas
    public let surface: Color         // fondo de pantalla
    public let surfaceRaised: Color   // tarjetas, hojas
    public let textPrimary: Color
    public let textSecondary: Color
    public let separator: Color
    public let positive: Color        // ingresos
    public let warning: Color         // presupuesto cerca del límite
    public let critical: Color        // sobregiro, errores
}
```

**Semánticos fijos:** `positive`, `warning` y `critical` **no cambian con el tema**.
Si el rojo de alerta cambiara según el tema, el usuario tendría que reaprender qué
significa. La personalización es identidad, no semántica.

## Los seis temas

Cada uno es un par primario/secundario. Todos verificados a 4.5:1 sobre `surface`
en claro y oscuro.

| Tema | Primario | Secundario |
|---|---|---|
| Cobalto *(default)* | `#1B4FD8` | `#F2B705` |
| Cempasúchil | `#E8590C` | `#6D3B8E` |
| Jacaranda | `#6C4FB3` | `#4FA88B` |
| Nopal | `#2F7A4F` | `#E0457B` |
| Bugambilia | `#C2185B` | `#F2A007` |
| Obsidiana | `#2B2B33` | `#C9A227` |

Los nombres vienen del mundo del usuario, no de la rueda de color. "Jacaranda"
comunica algo; "Morado 2" no.

**Al agregar un tema nuevo:** verifica contraste en claro y oscuro contra
`surface`, `surfaceRaised` y `textPrimary`, y confirma que la rampa de categorías
mantenga 8 tonos distinguibles entre sí. Un par que no pasa no entra.

## Colores de categoría

Se derivan de la rampa del tema, en orden fijo. **El usuario no elige el color de
una categoría.**

Suena restrictivo, pero es lo que evita que el dashboard se vuelva un arcoíris
donde ninguna gráfica se lee. Si el usuario quiere distinguir categorías, para eso
están los nombres y los íconos — ahí sí tiene libertad total, incluyendo emoji.

## Espaciado y tipografía

Unidad base 4pt. Solo se usan estos valores:

```swift
public enum Space { case xs, sm, md, lg, xl, xxl }  // 4, 8, 16, 24, 32, 48
```

Cualquier `.padding(17)` en el código es un bug. Escala tipográfica ligada a
Dynamic Type, nunca tamaños en puntos fijos.

**Los montos siempre con cifras tabulares** (`.monospacedDigit()`) y alineados a la
derecha. Sin esto, los números bailan entre renglones y una lista de gastos se ve
descuidada.

## Reglas al escribir vistas

- Ni un solo color literal fuera de `LanaDesign`. Ni `Color.blue`, ni
  `Color(red:green:blue:)`, ni `.tint(.orange)`.
- Ni un solo valor de espaciado literal. Todo sale de `Space`.
- Prueba en los 6 temas antes de dar algo por terminado. El `#Preview` debe
  iterarlos:

```swift
#Preview {
    ForEach(LanaTheme.allCases) { theme in
        EntryView().environment(\.lanaTheme, theme)
    }
}
```

- El color nunca es el único portador de información. Sobregiro lleva ícono o
  texto además del rojo — daltonismo y modo escala de grises existen.

## Tono

Lana no regaña. Un presupuesto excedido se presenta como un hecho con la acción
disponible al lado, no como una advertencia con signos de admiración. El usuario
de esta app ya abandonó otras; la última cosa que necesita es que su tracker lo
haga sentir mal por gastar.

Esto aplica al color tanto como al copy: usa `critical` donde hay algo que hacer,
no donde hay algo que juzgar.
