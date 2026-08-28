# ADR-0018: Adelantar un widget mínimo de captura a v1.0

- **Estado:** Aceptada
- **Fecha:** 2026-08-27

## Contexto

`CLAUDE.md` marcaba "App Intents" y "widgets" como fuera de v1.0 desde el
inicio del proyecto — decisión razonable en su momento, para no dispersar
esfuerzo antes de que el flujo de captura principal (voz + texto) estuviera
sólido. El usuario pidió explícitamente adelantar esto: "quiero continuar
con lo de los widgets para hacerlo rápido, solamente quiero presionar el
widget y pues ya hablo para decir lo que compré, y se guarda solo."

**Por qué esto no es "un widget" en el sentido que `CLAUDE.md` excluía.**
Lo que se pidió no es un widget informativo (mostrar saldos, gastos del
mes, deuda de tarjetas en la pantalla de inicio) — eso sigue siendo una
pieza de trabajo real, con su propio diseño de qué mostrar y cómo
mantenerlo actualizado. Lo que se pidió es un atajo de un toque: abrir la
app ya en modo escucha. Eso reduce el alcance real de "widgets" a algo
mucho más chico que lo que la exclusión original tenía en mente.

**Por qué esto también toca "App Intents".** Un widget no puede grabar
audio directamente — iOS no le da acceso al micrófono a una extensión de
WidgetKit. La única forma de lograr "un toque y ya estoy hablando" es que
el widget abra la app misma, ya sea vía un Intent (`AppIntent` con
`openAppWhenRun`) o vía un deep link con esquema de URL propio. Los dos
caminos "cuentan" como tocar la lista de exclusiones — se decidió avanzar
con el deep link por ser el más simple de los dos (sin necesidad de
declarar un `AppIntent` completo ni pensar en su exposición a Siri, que sí
sería un alcance mayor).

**Alternativas consideradas para "abrir y ya estoy hablando":**

- **`AppIntent` con `openAppWhenRun: true`.** Descartada para v1 de este
  widget — trae consigo la superficie completa de App Intents (exposición
  a Siri/Acciones Rápidas, `IntentDescription`, parámetros) para un caso
  de uso que no necesita nada de eso todavía. Un deep link cubre lo
  pedido con mucho menos código y menos superficie nueva que mantener.
- **Widget interactivo con botón que ejecuta una acción en segundo plano
  (sin abrir la app).** Descartada de raíz: grabar audio requiere UI en
  primer plano y permiso ya otorgado — no es algo que una extensión de
  widget pueda hacer aunque quisiera.
- **Deep link (`lana://capture`) que abre la app y arranca a escuchar.**
  Elegida — ver Decisión.

## Decisión

Un solo widget de Home Screen (tamaño chico), con un botón/superficie
completa que es un `Link` a `lana://capture`. Sin `TimelineProvider` real
— el contenido nunca cambia (un ícono de micrófono, nada de datos vivos),
así que una sola entrada estática alcanza. Nueva extensión de WidgetKit
(`LanaWidget`), agregada al proyecto de Xcode con la gema `xcodeproj`
(evita edición manual de `project.pbxproj`, alto riesgo de corromper el
archivo a mano).

La app registra el esquema de URL `lana` en `Info.plist`
(`CFBundleURLTypes`) y maneja el link con `.onOpenURL` en `ContentView`:
prende un estado `autoStartListening`, presenta la hoja de captura de
siempre (`EntryView`, sin pantalla nueva), y `EntryModel.onAppear(startListening:)`
(nuevo parámetro, default `false`) arranca `startListening()` en cuanto
`onAppear()` termina de revisar disponibilidad y cargar tarjetas/
subcategorías — mismo camino de captura que ya existía (ADR-0015: "es otra
forma de producir texto que alimenta el mismo parser"), no uno nuevo.

`autoStartListening` se apaga explícitamente al cerrar la hoja
(`onDone`), para que abrir la captura por el botón normal del micrófono
después no arranque a escuchar solo por accidente — es un atajo de una
sola vez, consumido, no un cambio de comportamiento default.

El widget no comparte datos con la app (sin App Group) — no necesita
leer nada del store, solo abrir un link. Si en el futuro se agrega un
widget informativo (saldos, deuda), ese sí va a necesitar un App Group
para leer `CoreDataExpenseStore` desde la extensión — vale la pena una
ADR propia cuando llegue ese momento, no se adelanta aquí.

## Consecuencias

**Bueno:**

- El camino de "quiero registrar algo" a "ya estoy hablando" baja a un
  solo toque desde la pantalla de inicio, sin abrir la app y buscar el
  botón del mic.
- Cero superficie nueva de dominio — reusa `EntryModel`/`EntryView`
  íntegros, sin un segundo camino de captura ni un segundo parser.
- La extensión no necesita App Group ni acceso a Core Data — superficie
  de código mínima, nada que sincronizar entre la app y el widget.

**Malo / a vigilar:**

- `CLAUDE.md` ya no excluye "widgets" como categoría completa — la
  próxima vez que se proponga un widget más ambicioso (uno informativo,
  con datos reales), ya no hay una barrera automática de "eso es v2"; la
  decisión de si vale la pena se toma caso por caso, no por default.
- Sin verificación en dispositivo real todavía dentro de esta sesión: el
  comportamiento del widget en Home Screen (que el sistema realmente lo
  ofrezca para agregar, que el deep link abra la app correctamente desde
  fuera de ella) necesita una prueba manual en el iPhone — el mismo
  espíritu que ya aplica a CKShare (ADR-0004) y a la detección de "test"
  del parser: esto no se puede medir desde este entorno de desarrollo.
- Un widget sin `TimelineProvider` real (una sola entrada estática) es lo
  más simple posible, pero significa que si algún día se quiere que el
  widget muestre algo dinámico (una racha de días registrando, por
  ejemplo), hay que revisar el `Provider` desde cero — no se diseñó
  pensando en crecer hacia eso.
