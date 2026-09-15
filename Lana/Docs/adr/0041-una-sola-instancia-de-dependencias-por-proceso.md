# ADR-0041: Una sola instancia de `AppDependencies` por proceso

- **Estado:** Aceptada
- **Fecha:** 2026-09-15

## Contexto

La captura de Apple Pay (ADR-0009) fallaba a veces y otras veces no, con el mismo atajo y
la misma tarjeta. Atajos terminaba con "hubo un error en la automatización".

`AddTransactionIntent` vive en el target de la app, así que corre **en el proceso de Lana**.
Tanto `ContentView` como el intent llamaban `AppDependencies.live()`, y cada llamada crea un
`CoreDataExpenseStore` nuevo, o sea un `NSPersistentCloudKitContainer` nuevo sobre el mismo
`.sqlite` y la misma zona de CloudKit. El del intent además nunca se cerraba.

- Lana cerrada: iOS la levanta solo para el intent, hay un único contenedor y guarda bien.
- Lana viva en segundo plano: ya tiene su contenedor abierto, el intent abre otro encima y el
  guardado falla.

Lo aleatorio era si Lana seguía en memoria al momento de pagar. Que dos contenedores sobre
el mismo archivo en el mismo proceso chocan ya estaba documentado (`LanaManagedObjectModel`,
`CoreDataExpenseStore.close()`, ADR-0014), pero solo se había evitado *dentro* de una
instancia de `AppDependencies`, no entre dos.

## Decisión

**`AppDependencies.shared()` es la única entrada en producción.** Guarda la `Task` de la
primera carga de `live()` y todas las llamadas siguientes esperan esa misma `Task`. La app y
el intent reciben el mismo objeto y, con él, el mismo contenedor.

Se cachea la `Task` y no la instancia para que dos llamadas simultáneas (la app arrancando
en frío justo cuando dispara el atajo) no carguen dos veces. Si la carga falla, la caché se
limpia y la siguiente llamada reintenta: un fallo de arranque no debe dejar la captura rota
hasta matar la app.

`live()` se queda como la construcción real, pero solo `shared()` la llama.

## Consecuencias

- El intent ya no depende de si la app estaba viva, que era la causa del "a veces".
- Cuando la app está viva, el intent también arranca más rápido: no vuelve a consultar la
  cuenta de iCloud ni a cargar el store.
- Una instancia que vive todo el proceso es estado global. Es aceptable porque esto ya era
  cierto en la práctica: `ContentView` la creaba una vez y la conservaba mientras vivía la app.
- `preview()` no pasa por aquí: los previews y los tests siguen creando instancias aisladas.

## Qué haría reconsiderar esto

- Mover el intent a una App Intents Extension. Correría en otro proceso, y el problema pasaría
  a ser coordinar dos procesos sobre el mismo store (App Group, historial persistente), no dos
  contenedores en uno.
