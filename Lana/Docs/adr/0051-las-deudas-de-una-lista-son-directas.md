# ADR-0051: Las deudas de una lista son directas, no simplificadas

- **Estado:** Superseded por ADR-0053
- **Fecha:** 2026-09-16
- **Relacionada:** ADR-0024 (detalle de deuda por gasto), ADR-0007 (proporción
  congelada)

## Contexto

La lista mostraba `PersonLedger.simplifiedDebts`: el mínimo de transferencias que
deja a todos en cero. El algoritmo empareja al mayor deudor con el mayor acreedor
y repite, así que el resultado es correcto en cifras pero no corresponde a ningún
gasto. En una lista de ocho donde pagaron dos personas, la pantalla decía
"Fernando te debe $128.46" y "Kin le debe a Iori $128.48", cuando Fernando y Kin
compartieron exactamente lo mismo y los dos les debían a los dos. El usuario lo
reportó dos veces como un error: "no tiene sentido lo que cada uno debe, todos los
gastos fueron en partes iguales".

ADR-0024 ya lo había visto venir: el detalle de una deuda (gasto por gasto) no
suma lo mismo que la deuda simplificada en listas de 3+, y dejó escrito que si se
volvía confuso habría que revisarlo.

Las alternativas:

- **Simplificada** (lo de antes). Menos transferencias, cifras que no se explican
  con los gastos.
- **Simplificada con una nota** de por qué no coincide. Explica la confusión en
  vez de quitarla.
- **Directa**: cada quien le debe a cada persona que pagó algo que compartió con
  él, neto entre los dos y menos lo que ya se liquidaron.

## Decisión

**La lista, la tarjeta de cada lista en Gente y la herramienta de saldos del
Análisis usan `PersonLedger.directDebts`.** Entre dos personas se netea: si Iori
me debe $100 de lo que pagué y yo le debo $50 de lo que pagó él, la pantalla dice
"Iori te debe $50".

Cada deuda coincide con la suma de `contributions(between:and:in:)` de ese par,
menos lo que ya se liquidaron entre los dos, así que su detalle siempre cuadra.

`simplifiedDebts` se queda en `LanaCore` con sus pruebas, sin uso en pantalla.

## Consecuencias

- Las deudas se explican con los gastos: quien compartió lo mismo debe lo mismo, a
  las mismas personas.
- **Más transferencias.** Con N personas y P que pagaron, puede haber hasta
  N × P filas en vez de N − 1. En una lista de viaje de ocho con dos pagadores son
  ~13 filas en lugar de 7.
- Las liquidaciones ya registradas bajo la vista simplificada se registraron entre
  un par concreto ("Kin le pagó a Iori"). Se descuentan de ese par, así que alguien
  que liquidó una deuda transitiva puede quedar con saldo a favor con uno y
  pendiente con otro. Los saldos netos no cambian; solo cómo se reparten.

## Qué haría reconsiderar esto

- Listas con muchos pagadores donde las filas directas se vuelvan inmanejables. Ahí
  la salida sería ofrecer "Simplificar" como acción explícita al liquidar, no volver
  a mostrarla por default.
