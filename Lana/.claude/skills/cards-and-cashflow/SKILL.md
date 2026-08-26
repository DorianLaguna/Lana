---
name: cards-and-cashflow
description: Modelo de tarjetas de crédito con ciclos de corte, deuda por tarjeta, método de pago y proyección de disponible por quincena en Lana. Usa esta skill siempre que el trabajo toque tarjetas, fechas de corte o límite, cuánto se debe a un banco, métodos de pago, la captura por Apple Pay, o cualquier cálculo de cuánto dinero queda disponible.
---

# Tarjetas y flujo de efectivo

## Método de pago

Va en el evento, no solo en el gasto — también aplica a liquidaciones, donde
importa si fue transferencia (hay comprobante) o efectivo (no hay).

```swift
enum PaymentMethod {
    case efectivo
    case debito(account: AccountID?)
    case credito(card: CardID)
    case transferencia(account: AccountID?)
}
```

Es **ortogonal al split**: con qué pagaste no altera cómo se divide la deuda entre
personas. Son dos dimensiones independientes del mismo evento.

## Tarjetas

```swift
struct Card {
    let alias: String        // "Nu", "BBVA Azul" — como le dice el usuario
    let lastFour: String     // NUNCA el número completo
    let creditLimit: Money
    let cutoffDay: Int       // día del corte
    let dueDay: Int          // fecha límite de pago
}
```

**Nunca guardes el número completo de una tarjeta, CVV ni fecha de vencimiento.**
No hay razón de producto para tenerlos y sí mucha responsabilidad. Alias y últimos
cuatro alcanzan para todo lo que hace la app.

## Los dos saldos de una tarjeta

Confundirlos es el error clásico y hace inútil la función:

- **Saldo actual** — todo lo gastado y no pagado
- **Saldo al corte** — lo que cerró en el último corte. *Este* es el que vence en
  la fecha límite y el que entra a la proyección.

Un gasto del día después del corte se paga hasta el siguiente ciclo — unos 50 días
de plazo. Uno del día antes, unos 20. Esa diferencia es lo que el usuario no ve y
la razón por la que esta función vale la pena.

Al registrar un gasto con tarjeta, dile a qué corte cae y cuándo se paga.

## Los ledgers son independientes

Un solo gasto compartido pagado con tarjeta genera **dos deudas separadas**:

```
Súper $1,200, pagó el usuario con Nu, proporcional 60/40

→ deuda con Nu:        $1,200   (el total; él lo cargó)
→ la pareja le debe:     $480   (su 40%)
```

Uno es contra el banco, otro contra una persona. Nunca los sumes ni los mezcles en
la misma vista de saldo.

## Proyección (ADR-0008)

**Solo cuenta lo que tiene fecha.**

```
Quincena del 15                    $18,000
Comprometido a fecha
  Pago Nu (vence 24)               -$3,400
  Pago BBVA (vence 20)             -$1,850
  Renta (vence 1)                  -$4,250
  ────────────────────────────────────────
  Disponible                        $8,500

Por cobrar (no incluido)
  Pareja                            $1,240
```

Las cuentas por cobrar van **abajo, separadas y con jerarquía visual menor**. Nunca
sumadas al disponible: ese dinero puede llegar en tres semanas y no sirve para
pagar la tarjeta el día 24.

Un disponible en el que el usuario no confía no se consulta, y consultarlo antes de
gastar es el propósito entero de la función.

## Apple Pay (ADR-0009)

No hay API. La app expone un App Intent y el usuario arma la automatización en
Shortcuts (trigger "Wallet" en iOS 26, "Transaction" antes).

**Toda transacción capturada así entra con `needsReview`.** El disparador tiene
fallas conocidas: se pasa de tiempo cuando el banco tarda, y se activa incluso en
transacciones rechazadas. Tratarlo como dato confirmado mete basura al registro.

Solo captura pagos NFC — nada de compras en navegador. Dilo en la guía de
configuración para que la ausencia no se lea como bug.

No se prueba en simulador. Requiere device físico con tarjetas reales en Wallet.

## Tono

Una tarjeta cerca del límite se muestra como dato con su acción al lado, no como
advertencia. Sin signos de admiración, sin rojo salvo que haya algo que hacer.
El usuario de esta app ya abandonó otros sistemas; no necesita que lo regañen.
