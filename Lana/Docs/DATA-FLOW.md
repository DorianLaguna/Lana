# Flujo de datos

De lo que el usuario escribe a lo que queda guardado, y de vuelta.

```
  CAPTURA          PARSEO         VALIDACIÓN      CONFIRMACIÓN
 ┌────────┐      ┌────────┐      ┌──────────┐    ┌──────────┐
 │ texto  │      │Foundat.│      │ regex    │    │  el      │
 │ ApplePay ──►  │ Models │  ──► │ filtros  │──► │ usuario  │
 │ ticket │      │+ vocab │      │ fuzzy    │    │ confirma │
 └────────┘      └────────┘      └──────────┘    └────┬─────┘
                      ▲                                │
                      │ vocabulario                    ▼
                 ┌────┴─────┐                    ┌──────────┐
                 │APRENDIZAJE│ ◄─── correcciones │  EVENTO  │
                 └──────────┘                    │inmutable │
                                                 └────┬─────┘
                                                      ▼
                        DERIVACIÓN            ┌──────────────┐
              ┌──────────────────────┐        │ PERSISTENCIA │
              │ ledger tarjetas      │ ◄───── │  Core Data   │
              │ ledger personas      │        │  + CloudKit  │
              │ proyección           │        └──────────────┘
              │ dashboard            │
              └──────────────────────┘
```

---

## 1. Captura — tres fuentes, un solo camino

| Fuente | Produce | Estado inicial |
|---|---|---|
| Texto escrito | string | normal |
| Apple Pay (App Intent) | monto, comercio, tarjeta | `needsReview` |
| Ticket escaneado | texto vía OCR | `needsReview` |

Las tres convergen en el mismo parser. Un ticket no tiene parser propio: OCR lo
convierte a texto y de ahí sigue igual (ADR-0010).

Lo automático entra siempre a revisión (ADR-0009, ADR-0010): el trigger de
Shortcuts dispara en transacciones rechazadas y el papel térmico se lee mal.

## 2. Parseo

`FoundationModels` con un `@Generable` que devuelve una lista de gastos.

Al prompt se le inyecta, **solo como etiquetas**:
- Subcategorías que el usuario ya tiene, por categoría
- Sus correcciones previas como pares `término → categoría`
- Sus tarjetas, por alias

Nunca cifras ni frases de ejemplo (ADR-0013).

Salida por gasto: `monto`, `concepto`, `categoría`, `subcategoría`,
`métodoDePago`, `necesitaRevisión`. En lista compartida se agrega `pagador` y
`reglaDeDivisión`.

## 3. Validación — determinista, sin modelo

Cuatro pasos en orden. Ninguno usa IA.

1. **Filtro de ceros.** `monto <= 0` se descarta. Un gasto de cero no existe.
2. **`AmountValidator`.** Regex sobre el texto crudo. Si el modelo devolvió una
   cifra que no está ahí → gana el regex y se marca `needsReview`.
3. **Conteo.** Si el regex encontró más números que gastos devueltos → posible
   gasto perdido → `needsReview`. Es señal, no rechazo: "2 boletos" tiene un
   número que no es monto.
4. **Fuzzy de subcategoría.** Levenshtein contra las existentes de esa
   categoría. Si nada se parece, se crea. `otro` y variantes no son válidas:
   mejor vacío (ADR-0011).

Si hay tarjeta de crédito, aquí se calcula **a qué corte cae** y cuándo se paga.

## 4. Confirmación

Se muestra el resultado con los campos editables. El usuario confirma o corrige.

**Guardar nunca se bloquea.** Si algo quedó ambiguo, entra con `needsReview` y se
resuelve después desde la bandeja. Un gasto incompleto vale más que uno que no
se registró.

## 5. Evento

Lo que se guarda es un **evento inmutable**, no un registro mutable (ADR-0005):

```
ExpenseAdded(id, monto, moneda, tasaDelDia, categoría, subcategoría,
             métodoDePago, tarjeta?, fecha, listaCompartida?, pagador?,
             splitRule?, needsReview)
```

- Editar → `ExpenseCorrected(correctsID, …)`
- Borrar → `ExpenseVoided(voidsID)`
- Liquidar deuda → `SettlementRecorded(…)`
- Pagar tarjeta → `CardPaymentRecorded(…)` — **no es un gasto**, o cuenta doble

En split proporcional, los shares se congelan en el evento (ADR-0007).

## 6. Persistencia

Core Data + `NSPersistentCloudKitContainer` (ADR-0004).

- Gasto personal → zona privada del usuario
- Gasto de lista compartida → **zona propia de esa lista**

Los registros de la zona por defecto no se pueden compartir, y eso no se
retrofitea. Por eso se decide aquí, no en la Fase 8.

## 7. Derivación — nada de esto se guarda

Todo se recalcula plegando los eventos:

| Vista | Se deriva de |
|---|---|
| Dashboard mensual | eventos del rango, agrupados |
| Saldo de tarjeta | eventos con esa tarjeta, partidos por ciclo de corte |
| Saldo con personas | eventos de la lista + liquidaciones, aplicando shares |
| Proyección | ingresos esperados − compromisos **con fecha** |
| Presupuesto | gastos del mes por categoría vs. límite |

**Los dos ledgers no se mezclan.** Un gasto compartido pagado con tarjeta genera
deuda con el banco *y* deuda con la persona. Sumarlos da un número sin
significado.

**La proyección solo cuenta lo que tiene fecha** (ADR-0008). Lo que te deben va
en sección aparte, nunca dentro del disponible.

## 8. Aprendizaje — el ciclo que cierra

Cuando el usuario corrige una categoría, se guardan **las palabras que él
escribió** (no el concepto que generó el modelo) con la categoría que eligió.

Eso alimenta el vocabulario del paso 2. Medido en el spike: 75% → 90% con 8
correcciones.

Se conservan las correcciones recientes y las más usadas, no todas: cada una
alarga el prompt y la latencia se nota en la pantalla de captura.

---

## Lo que nunca se guarda

- Saldos de cualquier tipo — siempre derivados
- Número completo de tarjeta, CVV, vencimiento — solo alias y últimos cuatro
- Montos convertidos de moneda — se guarda el original y la tasa del día
- Nada en servidores propios — no hay backend

## Dónde entra cada validación

```
modelo dice 45000  →  regex dice [45]        →  gana 45, needsReview
modelo dice 760    →  regex dice [300, 460]  →  needsReview (suma inventada)
modelo dice 380    →  regex dice [2, 380]    →  ok, pero marca el 2 sin reclamar
modelo dice 0      →  filtro                 →  descartado
"mil quinientos"   →  regex no encuentra     →  no se puede validar, pasa
```

Los cuatro primeros casos se observaron en el spike. No son hipotéticos.
