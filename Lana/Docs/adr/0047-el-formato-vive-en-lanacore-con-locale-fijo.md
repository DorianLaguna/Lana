# ADR-0047: Fechas y montos se escriben desde `LanaCore`, con locale fijo

- **Estado:** Aceptada
- **Fecha:** 2026-09-16
- **Relacionada:** ADR-0044 (sistema de diseño del rediseño)

## Contexto

El rediseño creó `LanaDateFormat` en `LanaDesign` porque la interfaz en español
mostraba "Tuesday, 15 September". Se barrieron las pantallas rediseñadas, pero
quedaron rincones sin barrer, y al revisarlos aparecieron tres problemas que son
el mismo problema:

1. **La app solo declaraba inglés.** `knownRegions = (en, Base)`, sin ningún
   `.lproj` ni región de desarrollo. `Locale.current` resolvía a inglés, así que
   **todo lo que se formateaba sin locale explícito salía en inglés en cualquier
   teléfono**. Comprobado ejecutando el formateador: `.dateTime.month(.wide).year()`
   devuelve "September 2026". Las etiquetas del selector de periodo del Análisis
   y la fecha de última sincronización de iCloud lo mostraban tal cual.
2. **`Money.formatted()` seguía al dispositivo.** Ahí no manda el idioma sino la
   región: en México da "$1,234.50", con región de Estados Unidos "MX$1,234.50"
   y en Alemania "1.234,50 MX$". Latente, pero son 60 llamadas.
3. **Un monto se escribía de dos maneras según la pantalla.** El Dashboard usaba
   `MoneyDisplay` (que sí fijaba el locale); Tarjetas, Gente y Análisis usaban
   `Money.formatted()` en crudo. `MoneyDisplay` existía precisamente para tapar
   el defecto del original.

El obstáculo para arreglarlo: el locale tenía que estar donde viven `Money` y
`LedgerToolbox` —`LanaCore`—, pero el formateador vivía en `LanaDesign`, y
`LanaCore` importa únicamente `Foundation` (Docs/ARCHITECTURE.md).

## Decisión

**`LanaDateFormat` se muda a `LanaCore`.** Escribir un monto o una fecha no es
una decisión de diseño: es cómo habla el producto. Las 15 features que lo usan
ya importaban `LanaCore`, así que la mudanza les fue transparente.

**`MonthSelector` recibe la etiqueta ya formateada**, no la fecha. Era lo único
dentro de `LanaDesign` que usaba el formateador. La alternativa —que `LanaDesign`
dependiera de `LanaCore`— habría metido una arista nueva en el grafo y abierto la
puerta a que el sistema de diseño conozca tipos del dominio. Cuesta un call site,
y de hecho cumple mejor el contrato que el propio componente ya declaraba: "solo
recibe primitivos".

**`Money.formatted()` fija el locale**, con lo que las 60 llamadas quedan
correctas sin tocar ninguna. `MoneyDisplay.full` pasa a delegar en él: un monto
se escribe igual en toda la app, lo pida quien lo pida. `whole`, `compact` y
`heroParts` se quedan porque sí hacen algo más.

**La app declara español**: `developmentRegion = es`, `es` en `knownRegions`, y
`CFBundleDevelopmentRegion`/`CFBundleLocalizations` en el `Info.plist`. El locale
explícito arregla lo que escribimos nosotros; esto arregla lo que pinta el
sistema —los nombres de mes del selector gráfico, los diálogos— que con el bundle
en inglés salían en inglés dentro de una app en español.

## Consecuencias

- Hay **una sola fuente de verdad** del locale, y está donde la puede usar tanto
  el dominio como la interfaz.
- El texto que devuelven las herramientas de análisis cambia de "September 2026"
  a "Septiembre 2026". Es texto que también consume el modelo al narrar, así que
  se fija con pruebas de igualdad exacta antes de refactorizar nada más ahí.
- `LanaDesign` sigue sin depender de `LanaCore`. El grafo de
  `Docs/ARCHITECTURE.md` no cambia.
- Cambiar el idioma declarado del bundle afecta la interfaz que aporta el
  sistema. Se verifica en el dispositivo, no en simulador.
