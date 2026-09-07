# ADR-0032: Un solo lugar decide qué se refresca cuando cambia un gasto

- **Estado:** Aceptada
- **Fecha:** 2026-09-01

## Contexto

El usuario reportó que, estando dentro del detalle de una tarjeta, capturar
un gasto para esa tarjeta no lo mostraba: había que salir y volver a entrar.
Y jalar hacia abajo para refrescar tampoco hacía nada.

Eran dos causas independientes que se veían como una sola:

1. **Cada hoja de `ContentView` traía su propia lista de refrescos.** La de
   editar un gasto refrescaba Dashboard, la lista de Tarjetas, el detalle de
   tarjeta empujado en el stack y la lista compartida — con un comentario
   explicando por qué el detalle necesita su propio refresco aparte. La de
   **capturar** refrescaba solo Dashboard y Compartido. Nadie actualizó la
   segunda cuando se agregó el caso de Tarjetas a la primera.
2. **`CardDetailView` no tenía `.refreshable`.** `CardsView` (la lista) sí.
   Así que el gesto de refrescar en el detalle no estaba conectado a nada —
   no es que trajera datos viejos, es que no corría nada.

La plomería para lo primero ya existía y era correcta
(`CardsModel.refreshCurrentCardDetail()`, que opera sobre la instancia
reutilizada del detalle en pantalla). Solo no se llamaba desde ese camino.

## Decisión

**Las superficies que dependen de los gastos se enumeran una sola vez**, en
`MainTabView.refreshAfterExpenseChange()`. Las dos hojas (capturar y editar)
llaman a ese método y nada más.

Hay una segunda variante, `refreshSurfacesOutsideDashboard()`, para el aviso
que viene desde dentro del propio Dashboard (`DashboardView` refresca su
modelo y *luego* llama a `onExpenseChanged`). Refrescarlo otra vez sería una
lectura de más y un parpadeo de su spinner. La primera llama a la segunda, así
que la lista de "las demás superficies" sigue existiendo en un solo lugar: la
diferencia entre ambas es solo el Dashboard, explícita y justificada.

`CardDetailView` gana `.refreshable`, igual que la lista.

## Consecuencias

**Bueno:**

- Agregar una pantalla nueva que dependa de los gastos es un renglón en un
  método, no una revisión de cada `onDone` para ver cuál se olvidó. El bug
  fue exactamente eso: dos listas que debían decir lo mismo y no lo decían.
- El gesto de refrescar funciona donde el usuario ya esperaba que
  funcionara.

**Malo / a vigilar:**

- Ahora **toda** creación o edición de un gasto refresca las cuatro
  superficies, aunque solo una esté en pantalla. Son lecturas locales de
  SQLite y en la práctica es imperceptible, pero es trabajo de más a
  propósito: se prefiere sobre volver a tener listas parciales que se
  desincronizan.
- El corte entre las dos variantes depende de un detalle de `DashboardView`
  (que se refresca a sí mismo antes de avisar). Si eso cambiara, el
  Dashboard dejaría de actualizarse en ese camino sin que nada lo señale.
- Nada de esto es verificable con un test: es glue de SwiftUI en
  `ContentView`. Lo que sí quedó cubierto es el contrato del que depende
  (`CardsModelRefreshTests`): que `makeCardDetailModel` reutilice la
  instancia en pantalla y que refrescarla recoja un gasto recién guardado.
  Si eso se rompe, el síntoma vuelve — y ahí sí falla una prueba.
