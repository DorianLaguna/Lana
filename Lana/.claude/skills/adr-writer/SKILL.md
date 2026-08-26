---
name: adr-writer
description: Redactar un Architecture Decision Record para el proyecto Lana. Usa esta skill siempre que se tome una decisión sobre estructura, dependencias, modelo de datos, límites de plataforma o cualquier cosa que un desarrollador futuro podría querer revertir sin saber por qué existe — aunque el usuario no pida un ADR explícitamente.
---

# Escribir un ADR

Los ADRs son la memoria del proyecto (ADR-0001). Un buen ADR le contesta a tu yo
de dentro de seis meses la pregunta "¿por qué está así y qué se rompe si lo cambio?".

## Cuándo escribir uno

- Elegir entre tecnologías o enfoques
- Agregar o quitar una dependencia externa
- Cambiar límites entre módulos
- Cambiar el modelo de datos de forma no trivial
- Aceptar conscientemente una limitación
- Revertir o modificar una decisión anterior

Un cambio de implementación dentro de límites existentes no lleva ADR.
Un cambio que altera lo que es posible después, sí.

## Formato

```markdown
# ADR-NNNN: <título en imperativo, la decisión no el tema>

- **Estado:** Propuesta | Aceptada | Superseded por ADR-NNNN
- **Fecha:** YYYY-MM-DD

## Contexto
Qué problema hay y qué fuerzas están en tensión. Presenta las alternativas reales
que se consideraron con sus tradeoffs honestos — un ADR con una sola alternativa
no documenta una decisión, documenta una conclusión.

## Decisión
Qué se decidió, en voz activa y presente. Específico y sin hedging.

## Consecuencias
Lo bueno y lo malo. La sección de consecuencias negativas es la más valiosa del
documento: es lo que le dice a tu yo futuro qué costo estás pagando y bajo qué
condiciones valdría la pena revisitar.
```

## Qué hace bueno a un ADR

Nombra los tradeoffs de verdad. "Elegimos X porque es mejor" no es un ADR, es una
afirmación. "Elegimos X aceptando que perdemos Y, porque en nuestro contexto Z
pesa más" sí lo es.

Sé concreto sobre el costo. ADR-0002 dice que el mercado se reduce
significativamente en México — eso es útil. "Puede haber algunas limitaciones" no
lo es.

Deja escrito qué haría reconsiderar la decisión. Es lo que convierte al ADR en
algo vivo en vez de un trámite.

## Superseder

No edites un ADR aceptado. Escribe uno nuevo, y en el viejo cambia solo la línea
de estado a `Superseded por ADR-NNNN`. El historial de decisiones equivocadas es
tan útil como el de las correctas.

## Numeración

Revisa `Docs/adr/` para el siguiente número disponible. Nombre de archivo:
`NNNN-slug-corto.md`.
