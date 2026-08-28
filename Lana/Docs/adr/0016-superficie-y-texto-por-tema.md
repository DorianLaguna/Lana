# ADR-0016: Mover superficie y texto a `ThemePalette`, uno por tema

- **Estado:** Aceptada
- **Fecha:** 2026-08-27

## Contexto

Desde ADR-0006, cada tema define su propio primario (`accent`) y secundario
(`highlight`), pero `surface`/`surfaceRaised`/`textPrimary`/`textSecondary`/
`separator` eran 10 constantes globales en `LanaColors`, compartidas por
los 6 temas. El doc comment del archivo lo decía explícito: "Fijos en
todos los temas". El único lugar donde el color de tema realmente se veía
era en detalles pequeños — el degradado del micrófono, un ícono, un chip
seleccionado. El fondo y el texto de toda la app seguían siendo los mismos
sin importar qué tema se eligiera, así que elegir un tema se sentía como
elegir un acento, no un tema real.

El usuario pidió específicamente que Obsidiana se sienta "siempre oscuro"
— fondo casi negro sin importar si el sistema está en modo claro u
oscuro. Esto no se resuelve con un tinte a la misma luminosidad que usan
los otros 5 temas: en modo claro del sistema, ese tinte seguiría
resolviendo a un fondo casi blanco (`surfaceLight` seguía siendo la
constante global `#FFFFFF`), porque `LanaColors.init` elige entre la
variante clara/oscura de cada token según `colorScheme`, no según el
tema. Obsidiana necesitaba un fondo oscuro **forzado**, no condicionado al
modo del sistema.

Alternativas consideradas:

- **Mecanismo dinámico de "forzar oscuro" a nivel de `LanaColors`** (p.
  ej. que `LanaColors.init` ignore `colorScheme` cuando el tema es
  Obsidiana y siempre calcule como si fuera oscuro). Descartada: es una
  capa de indirección extra — una regla especial dentro del inicializador
  — para lograr algo que un valor hex fijo por variante ya resuelve
  directamente, sin ramas nuevas de lógica.
- **Dejar Obsidiana con un tinte sutil, como los demás 5 temas.**
  Descartada: no cumple el pedido — seguiría viéndose claro cuando el
  sistema está en modo claro, que es exactamente lo que el usuario dijo
  que no quería.
- **Mover superficie/texto a `ThemePalette`, con Obsidiana usando valores
  casi negros en ambas variantes.** Elegida — ver Decisión.

## Decisión

`surfaceLight`/`surfaceDark`/`surfaceRaisedLight`/`surfaceRaisedDark`/
`textPrimaryLight`/`textPrimaryDark`/`textSecondaryLight`/
`textSecondaryDark`/`separatorLight`/`separatorDark` se mueven de
constantes globales en `LanaColors` a 10 campos más en `ThemePalette`
(`LanaTheme.swift`) — uno por tema, no uno compartido.

Para 5 de los 6 temas (cobalto, cempasúchil, jacaranda, nopal,
bugambilia), estos 10 valores copian tal cual los que ya eran globales —
cero regresión visual. Un `fileprivate init` en `ThemePalette` los aplica
por default, así que esos 5 casos del switch en `LanaTheme.palette` no
cambian de forma (siguen pasando solo `primaryLight`/`primaryDark`/
`secondaryLight`/`secondaryDark`).

Obsidiana usa valores casi negros — `#0A0A0C` de superficie, `#151517`
elevada — **en sus dos variantes** (`Light` y `Dark`), no solo en la
oscura. Esto es lo que logra "siempre se ve oscuro": el color no depende
de qué variante resuelva `colorScheme`, porque ambas variantes ya son la
misma. `primaryLight`/`secondaryLight` de Obsidiana también cambian, de
`#2B2B33`/`#8D711B` (tonos diseñados para verse sobre un fondo blanco) a
los mismos valores que `primaryDark`/`secondaryDark` (`#7D7D91`/
`#C9A227`) — con el fondo forzado a negro en ambas variantes, el tono
"pensado para claro" ya no tiene contra qué funcionar; sin este cambio,
`palette.primaryLight.contrastRatio(with: palette.surfaceLight)` cae a
~2:1, muy por debajo del mínimo.

`positive`/`warning`/`critical` — los 3 semánticos de estado — siguen
fijos y globales en `LanaColors`. ADR-0006 sigue vigente para esos: no se
tocan aquí.

Además, `ContentView`/`MainTabView` aplica `.preferredColorScheme(.dark)`
cuando el tema activo es Obsidiana (`nil` para los otros 5, que siguen el
sistema normal). `LanaColors` solo controla lo que Lana dibuja — la barra
de estado, el teclado y cualquier chrome nativo de UIKit/SwiftUI quedaban
siguiendo el modo real del sistema sin esto, rompiendo la sensación de
"todo se siente oscuro" fuera de lo que la app pinta directamente.

Al reescribir `LanaThemeContrastTests` para verificar cada tema contra su
propia superficie (antes probaba contra las 2 constantes globales, ahora
contra `palette.surfaceLight`/`palette.surfaceDark` de cada tema) se
agregó también una verificación que no existía: `textPrimary`/
`textSecondary` contra `surfaceRaised`, no solo contra `surface`. Esto
sacó a la luz un bug real preexistente, sin relación con Obsidiana:
`textSecondaryDark` (`#7F7F7F`) pasaba 4.5:1 contra `surfaceDark`
(`#121212`) pero no contra `surfaceRaisedDark` (`#1E1E22`) — 4.15:1. Se
corrigió a `#8A8A8A`, que sí pasa contra ambas, para los 5 temas que
comparten este valor.

La suite también excluye a Obsidiana de la verificación de
`positiveLight`/`warningLight`/`criticalLight` contra su superficie: con
`.preferredColorScheme(.dark)` forzado, esa combinación — un semántico
"claro" junto a la superficie de Obsidiana — es un estado que la app
nunca produce. Sí se verifica la variante oscura de esos 3 semánticos
contra la superficie de Obsidiana, que es la que realmente se usa.

## Consecuencias

**Bueno:**

- Elegir un tema ahora cambia la app entera, no solo acentos — el pedido
  original del usuario.
- Obsidiana se ve oscuro de punta a punta, sin depender del modo del
  sistema, incluyendo chrome nativo que Lana no dibuja.
- La suite de contraste reescrita agarra un bug real que la anterior no
  cubría (`textSecondaryDark` contra `surfaceRaisedDark`), no solo el
  caso nuevo de Obsidiana.

**Malo / a vigilar:**

- El invariante "Fijos en todos los temas" documentado en el doc comment
  de `LanaColors.swift` y en `.claude/skills/theming/SKILL.md` queda
  revertido para superficie/texto — sigue vigente solo para
  `positive`/`warning`/`critical`. Cualquier código o documentación nueva
  que asuma "la superficie es la misma en los 6 temas" está asumiendo mal
  desde este ADR en adelante.
- Los 5 temas que no son Obsidiana repiten los mismos 10 valores de
  superficie/texto — no hay verdadera variación de tema ahí todavía, solo
  la infraestructura para tenerla. Si en el futuro se quiere que, por
  ejemplo, Cempasúchil tenga una superficie con un tinte cálido sutil, el
  lugar para eso ya existe (`ThemePalette` por tema); hoy simplemente no
  se usó, a propósito, para no arriesgar regresión visual fuera de
  Obsidiana.
- Obsidiana ya no distingue entre su variante "clara" y "oscura" en
  ningún token propio (todos son iguales en ambas). Si alguna vista
  construye `LanaColors(theme: .obsidiana, colorScheme:)` pasando
  `.light` explícitamente esperando algo distinto de `.dark`, no lo va a
  obtener — es la intención, pero vale la pena tenerlo presente si
  aparece un caso de uso legítimo para diferenciarlas.
- `positiveLight`/`warningLight`/`criticalLight` ya no están verificados
  por la suite contra la superficie de Obsidiana. Si algún día
  `.preferredColorScheme(.dark)` deja de forzarse para Obsidiana (por
  ejemplo, si se vuelve configurable), esa combinación se vuelve
  alcanzable de nuevo y la exclusión en `LanaThemeContrastTests` habría
  que quitarla — y probablemente ajustar esos 3 hex, porque hoy no pasan
  4.5:1 contra `#0A0A0C`.
