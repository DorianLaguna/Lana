# ADR-0053: Para quedar a mano, cada quien paga o cobra exactamente su saldo

- **Estado:** Aceptada
- **Fecha:** 2026-09-16
- **Supersede:** ADR-0051 (las deudas de una lista son directas)
- **Relacionada:** ADR-0024 (detalle de deuda por gasto)

## Contexto

La lista de "Para quedar a mano" cambió dos veces el mismo día, y las dos veces el
usuario dijo lo mismo: no tiene sentido.

1. **Simplificada** (`simplifiedDebts`). Emparejaba al mayor deudor con el mayor
   acreedor. Las cifras cuadraban, pero quienes compartieron lo mismo aparecían
   debiéndole a personas distintas.
2. **Directa** (ADR-0051). Cada quien le debía a cada persona que pagó algo. Se
   explicaba con los gastos, pero hacía ir y venir el dinero: el saldo de arriba
   decía "debes $21.21" y abajo había que pagar $93 y cobrar $72. El número de
   arriba y la lista medían cosas distintas.

Lo que el usuario espera, dicho con sus palabras: si dice que debo $21.21, eso es
lo que pago. Y si Fernando y Kin compartieron lo mismo, deben lo mismo a los
mismos.

La simplificación cumple lo primero y no lo segundo; la directa, al revés.

## Decisión

**Cada deudor reparte su saldo entre quienes cobran, en proporción a lo que cobra
cada uno** (`PersonLedger.settlementPlan`). Si Iori cobra el 55 % de lo que se
debe en la lista, recibe el 55 % de lo que debe cada deudor.

- Nadie paga y cobra a la vez: quien tiene saldo a favor solo recibe.
- Lo que paga cada deudor suma su saldo, y lo que recibe cada acreedor suma el
  suyo, al centavo. Los centavos se reparten por mayor residuo y, si una columna
  queda descuadrada, se mueve un centavo dentro de una fila.
- Quienes compartieron lo mismo tienen el mismo saldo, así que deben lo mismo a
  cada quien (con un centavo de diferencia como máximo).

**El detalle de una fila explica esa cuenta** en vez de listar gastos entre dos
personas, que ya no suman la fila: "Debes $21.21 en total. Iori cobra $345.77 de
los $632.27 que se deben, el 55 %, así que le toca esa parte de lo tuyo: $11.60".
Debajo, el saldo de quien debe, movimiento por movimiento
(`PersonLedger.balanceEntries`), sumando exactamente su saldo.

`directDebts` se borra. `simplifiedDebts` y `contributions(between:and:in:)` se
quedan en `LanaCore` con sus pruebas, sin uso en pantalla.

## Consecuencias

- El saldo de arriba y la lista de abajo dicen lo mismo, y la simetría entre
  quienes compartieron igual se respeta.
- **Más filas que la simplificación**: deudores × acreedores. Con seis que deben y
  dos que cobran son doce, contra siete.
- **Una fila no corresponde a gastos entre esas dos personas.** "Le debes a Liz
  $9.61" puede salir aunque Liz nunca pagó nada que compartieras con ella
  directamente, si Liz cobra en la lista. El detalle lo explica, pero es menos
  intuitivo que la vista directa para quien piensa en gastos concretos.
- Una liquidación entre un par cambia los saldos, y el plan de todos se recalcula:
  pagarle a Iori puede mover centavos de lo que otros le deben a Liz.

## Qué haría reconsiderar esto

- Que el caso de la tercera consecuencia genere reclamos: "yo no le debo nada a
  Liz". La salida sería mostrar la vista directa como detalle secundario, no volver
  a ponerla como lista principal.
- Listas con muchos acreedores, donde deudores × acreedores se vuelva largo. Ahí sí
  valdría ofrecer la simplificación como acción explícita.
