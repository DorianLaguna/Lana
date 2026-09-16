# ADR-0052: Quitar a alguien de una lista solo si no deja dinero sin dueño

- **Estado:** Aceptada
- **Fecha:** 2026-09-16
- **Relacionada:** ADR-0050 (sumar a alguien nuevo a lo ya registrado), ADR-0005
  (eventos append-only), ADR-0028 (edición de la lista)

## Contexto

`EditSharedListModel` no dejaba quitar participantes, a propósito: un participante
puede tener gastos y liquidaciones a su nombre, y quitarlo del roster no borra esos
eventos. Su saldo quedaría sin nombre que mostrar (`SharedListDetailModel.load`
descarta lo que no resuelve a un `Participant`), que es perder dinero de vista en
silencio.

El usuario lo pidió: agregó a alguien por error, o de más, y no tenía forma de
corregirlo. ADR-0050 dejó anotado que quitar necesitaba su propio ADR.

No todo participante deja la misma huella:

- **Solo tiene partes en gastos iguales.** Esas partes se pueden repartir entre los
  demás sin decidir nada por nadie.
- **Pagó un gasto.** Ese dinero tiene que acreditársele a alguien, y no hay a quién.
- **Tiene liquidaciones.** Lo que pagó o recibió no tiene a dónde irse.
- **Está en un porcentaje o monto exacto.** Repartir su parte entre los demás es
  inventar un acuerdo que nadie hizo.

## Decisión

**Se puede quitar a alguien solo si su única huella en la lista son partes de
gastos iguales, y si no es quien mira.** En cualquier otro caso la fila no ofrece
"Quitar" y dice por qué: "Pagó gastos en esta lista", "Tiene pagos registrados en
esta lista", "Está en gastos divididos por porcentaje o montos", "Eres tú en esta
lista". Quien se acaba de agregar en la misma edición siempre se puede quitar.

**Al guardar, primero sale de sus gastos y después se guarda la lista.** Cada gasto
en que estaba emite un `ExpenseCorrected` con la división sin él
(`SplitRule.excluding(_:)`). Así ningún gasto queda apuntando a alguien que ya no
está en el roster, ni siquiera por un momento.

La hoja confirma antes de quitar, con cuántos gastos se ven afectados. La misma
hoja deja sumar a un participante ya guardado a los gastos anteriores de partes
iguales, para quien se agregó antes de que existiera la pregunta de ADR-0050.

## Consecuencias

- Corregir un roster mal capturado ya no obliga a crear otra lista.
- **Quien pagó algo no se puede quitar nunca**, ni aunque sus gastos se muevan a
  otra persona después. Para quitarlo hay que corregir o borrar esos gastos primero.
- Quitar a alguien sube la parte de los demás en esos gastos. Si alguno ya había
  liquidado contra la división anterior, queda debiendo la diferencia.
- Si la lista se comparte por iCloud y otro dispositivo registra un gasto con esa
  persona mientras tanto, ese gasto llega apuntando a alguien que ya no está. No se
  resuelve aquí.

## Qué haría reconsiderar esto

- Que se pida quitar a alguien que pagó. La salida sería reasignar sus gastos a otra
  persona como parte de la misma edición, no dejar su saldo sin dueño.
