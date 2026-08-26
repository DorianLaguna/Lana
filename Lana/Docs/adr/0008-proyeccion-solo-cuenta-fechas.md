# ADR-0008: La proyección solo cuenta compromisos con fecha

- **Estado:** Aceptada
- **Fecha:** 2026-08-23

## Contexto

La proyección de quincena responde "¿cuánto me sobra?". Hay tres tipos de cifras
que podrían entrar:

1. Dinero real disponible
2. Compromisos con fecha cierta (pago de tarjeta que vence el 24, renta el 1)
3. Cuentas por cobrar sin fecha (lo que debe la pareja en la lista compartida)

Meter (3) en el cálculo produce un número inflado: ese dinero puede llegar en tres
semanas, y no sirve para pagar la tarjeta el día 24.

Un número de disponible en el que el usuario no confía no se usa. Y el propósito
entero de esta función es que el usuario lo consulte antes de gastar.

## Decisión

El disponible proyectado se calcula solo con (1) y (2).

Las cuentas por cobrar se muestran en una sección aparte, claramente marcada como
no incluida. Al registrarse una liquidación, el dinero entra como real y el
disponible sube.

Los saldos compartidos **no tienen fecha de vencimiento**. Entre pareja la deuda es
informal y se compensa con el tiempo; imponer un ciclo de corte agregaría
burocracia y produciría un número vencido que el usuario aprendería a ignorar.

En su lugar, un recordatorio suave cuando el saldo cruza un umbral configurable de
monto o antigüedad. Es un dato, no una alerta: sin colores de urgencia y sin tono
de reclamo.

## Consecuencias

- El disponible siempre es conservador. Nunca promete dinero que no llegó.
- Se requiere una sección adicional en la UI, con jerarquía visual claramente
  menor que la del disponible.
- El umbral del recordatorio necesita default razonable y ser ajustable. Un
  recordatorio que aparece muy seguido se vuelve ruido y se ignora.
- La vista de saldo compartido prioriza la **tendencia** sobre el número puntual:
  un saldo que oscila alrededor de cero no requiere acción; uno que crece siempre
  hacia el mismo lado sí. Mostrar solo el número pierde esa distinción.
