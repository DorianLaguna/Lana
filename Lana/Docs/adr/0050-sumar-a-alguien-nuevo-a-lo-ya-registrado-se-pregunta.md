# ADR-0050: Sumar a alguien nuevo a lo ya registrado se pregunta, y es una corrección

- **Estado:** Aceptada
- **Fecha:** 2026-09-16
- **Relacionada:** ADR-0005 (eventos append-only), ADR-0007 (proporción congelada
  en el evento), ADR-0023 (corrección de pagador y split)

## Contexto

Cada gasto compartido guarda con quién se dividió: `.equally(among:)` lleva la lista
de participantes de ese momento. Si a una lista con gastos se le agrega a alguien
que faltaba, esos gastos siguen divididos entre los de antes, y el nuevo no debe
nada de lo ya registrado. El usuario lo reportó como un error: agregó a una persona
que había olvidado y los saldos no cambiaron.

ADR-0007 dice que el historial no se recalcula: cambiar la proporción de la lista
aplica hacia adelante. Ese ADR protege algo real —que un gasto de marzo no cambie
porque en junio subió un ingreso—, pero no distingue entre "la lista cambió" y "la
lista estaba mal desde el principio". Las dos cosas pasan, y se ven igual desde el
código:

- **Alguien faltaba.** Iba en el viaje desde el primer día y no se capturó. Lo
  correcto es que cuente en todo.
- **Alguien se sumó a la mitad.** Llegó el tercer día. No debe los gastos de antes.

Se consideraron tres salidas:

- **Recalcular siempre.** Resuelve el primer caso y rompe el segundo, en silencio.
- **Nunca recalcular** (lo de hoy). Obliga a editar gasto por gasto.
- **Preguntar al agregar**, y aplicar la respuesta como corrección.

## Decisión

**Al guardar una lista con participantes nuevos, si hay gastos a los que se podría
sumar, la app pregunta**: "¿Sumar a Kin a los 12 gastos que ya están?". "Sí" los
divide entre todos; "Solo lo nuevo" deja el historial como estaba.

**Solo aplica a partes iguales** (`SplitRule.including(_:)`). En porcentaje, montos
exactos o proporcional no hay forma segura de decidir cuánto le tocaría al nuevo:
quitarle a cada quien en proporción sería inventar un reparto que nadie acordó.

**Cada gasto afectado emite un `ExpenseCorrected` con su nueva división.** Nada se
reescribe ni se borra (ADR-0005), y los saldos se recalculan solos al plegar.

ADR-0007 sigue vigente: cambiar ingresos o la división por defecto no toca lo
registrado. Lo que cambia es que agregar a alguien ahora es una decisión explícita
del usuario sobre el historial, no un recálculo automático.

## Consecuencias

- Olvidar a alguien al crear una lista deja de costar editar cada gasto.
- **Las liquidaciones ya registradas no se ajustan.** Si alguien ya había pagado lo
  que debía, al sumar a una persona más su deuda baja y la liquidación lo deja con
  saldo a favor. Es correcto (pagó de más contra la nueva división), pero puede
  sorprender.
- La pregunta es todo o nada: no deja elegir gasto por gasto. Para el caso "llegó
  al tercer día" hay que responder "Solo lo nuevo" y sumarlo a mano a los gastos
  que sí le tocan.
- Un gasto con división personalizada queda fuera sin avisar cuál. La alerta lo
  dice en general, no gasto por gasto.

## Qué haría reconsiderar esto

- Que el caso "se sumó a la mitad" resulte común. La salida sería preguntar desde
  qué fecha cuenta, no volver a recalcular siempre.
- Que se pida lo mismo al **quitar** a alguien. Hoy no se puede quitar a nadie de
  una lista (`EditSharedListModel`), y hacerlo con gastos a su nombre necesita su
  propio ADR.
