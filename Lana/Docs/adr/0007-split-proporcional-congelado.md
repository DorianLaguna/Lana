# ADR-0007: La proporción de un split se congela en el evento

- **Estado:** Aceptada
- **Fecha:** 2026-08-23

## Contexto

La regla de división principal de la lista compartida es proporcional al ingreso
de cada participante — por ejemplo 60/40. Los ingresos cambian con el tiempo.

Si el evento guardara solo "proporcional" y el saldo se calculara con los ingresos
vigentes, un cambio de sueldo recalcularía retroactivamente toda la deuda histórica.
Gastos de hace seis meses cambiarían de monto. Eso vuelve el saldo imposible de
verificar y destruye la confianza en el número, que es lo único que importa cuando
hay dinero entre dos personas.

## Decisión

`SplitRule.proportional` guarda las **participaciones concretas** usadas en el
momento del registro, no una referencia a los ingresos.

```swift
case proportional(shares: [ParticipantID: Decimal])   // [dorian: 0.6, ella: 0.4]
```

La lista guarda la proporción vigente y la app la pre-llena al registrar, pero lo
que se persiste en el evento son los números.

Cambiar la proporción de la lista aplica **hacia adelante**. Los eventos previos no
se tocan — cosa que el modelo append-only (ADR-0005) ya garantiza por construcción.

## Consecuencias

- Un saldo calculado hoy da el mismo resultado que dentro de dos años.
- La UI debe mostrar la proporción usada en cada gasto, no la actual de la lista,
  o el usuario se confunde al revisar el historial.
- Cambiar la proporción requiere una acción explícita. No se hereda de un cambio
  de ingreso configurado en el perfil — eso sería la retroactividad por la puerta
  de atrás.
