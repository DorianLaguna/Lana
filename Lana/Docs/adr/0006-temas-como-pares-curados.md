# ADR-0006: Personalización de color con pares curados, no selector libre

- **Estado:** Aceptada
- **Fecha:** 2026-08-23

## Contexto

Se quiere que la app se sienta personal. La solución obvia es un color picker que
deje elegir primario y secundario libremente.

Esa solución tiene tres problemas concretos: dos colores arbitrarios se pelean
visualmente; el contraste puede caer debajo de 4.5:1 y romper accesibilidad sin que
el usuario lo note; y la app pierde identidad visual — deja de ser reconocible.

## Decisión

El usuario elige entre seis **pares** primario/secundario diseñados y verificados,
no colores sueltos.

Los colores semánticos de estado (`positive`, `warning`, `critical`) no cambian con
el tema. Si el rojo de alerta variara según la elección del usuario, tendría que
reaprender qué significa cada color.

Los colores de categoría se derivan de la rampa del tema en orden fijo. El usuario
personaliza nombres e íconos de categorías libremente, pero no sus colores.

## Consecuencias

- Cualquier combinación que el usuario elija se ve bien y cumple contraste.
- La app conserva identidad visual reconocible en las seis variantes.
- Se pierde personalización granular. Es un intercambio deliberado: el usuario que
  quiere su hex exacto no queda satisfecho, pero es una minoría frente al usuario
  que quiere que se vea bien sin pensarlo.
- Agregar un tema exige verificar contraste en claro y oscuro, y que la rampa de
  categorías mantenga ocho tonos distinguibles. Un par que no pasa no entra.
