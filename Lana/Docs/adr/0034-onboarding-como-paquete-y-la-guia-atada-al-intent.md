# ADR-0034: El onboarding es un paquete propio, y su guía queda atada a los parámetros reales del intent

- **Estado:** Aceptada
- **Fecha:** 2026-09-07

## Contexto

Se implementó una guía que le enseña al usuario a configurar el registro
automático de Apple Pay (el atajo de Shortcuts de ADR-0009/ADR-0019). Llegó
con estructura nueva que ningún ADR cubría: un paquete `OnboardingFeature`,
un protocolo `ApplePayEnvironmentProbing` en `LanaCore` con su implementación
`ApplePayEnvironmentProbe` en el target de la app, y un cambio en el arranque
— `ContentView` ahora bifurca entre onboarding y `MainTabView` según una
bandera en `UserDefaults`.

Una revisión encontró dos defectos que importan más que la estructura:

1. **La guía enseñaba a armar el atajo de la forma que ya sabíamos rota.**
   Conocía tres parámetros (`amount`, `merchant`, `cardName`) mientras
   `AddTransactionIntent` tiene seis. Faltaban justo `amountText` y
   `transactionText`, los dos que ADR-0033 agregó porque Wallet entrega el
   monto vacío al momento del tap. Un usuario que siguiera la guía al pie de
   la letra reproducía la configuración que no registra nada, y el aviso solo
   aparece en Atajos — desde Lana el síntoma es "mis pagos no salen", sin
   pista. La causa: la spec de la feature quedó congelada antes de ADR-0033 y
   nadie la reconcilió.
2. **El onboarding se le habría aparecido a todos los usuarios existentes.**
   `UserDefaults.bool(forKey:)` no distingue "false" de "nunca se escribió",
   así que en la primera actualización que trajera la feature, quien ya usaba
   Lana arrancaba en una guía sobre una función opcional en vez de en su app.

## Decisión

**`ParameterMapping` deja de asumir una biyección.** El modelo original
mapeaba uno a uno (monto→monto, comercio→comercio, tarjeta→tarjeta) y por eso
no podía expresar lo que ADR-0033 necesita: la MISMA variable de Wallet
alimentando dos campos distintos del intent («Monto» y «Monto como texto»).
Ahora `id` es el `intentParameter` — hay exactamente un mapeo por campo de la
acción, y la variable de Wallet puede repetirse. Los `intentLabel` pasan a ser
los títulos textuales de cada `@Parameter`, no descripciones: el usuario los
busca en pantalla, y aproximarlos no sirve.

**La atadura guía↔intent es un comentario en ambos lados, no el compilador.**
Se consideró invertir la dependencia (que `AddTransactionIntent` tome sus
títulos de `GuiaApplePayContent`) para que el compilador garantizara la
alineación. No se puede: `@Parameter(title:)` exige un literal para la
extracción de localización, no acepta un `String` de runtime. Y un test que
compare ambos lados tendría que vivir en el target de la app, que no se puede
probar sin simulador — y esta máquina no logra crear uno. Se acepta la
limitación explícitamente: una nota en `AddTransactionIntent` y su gemela en
`ParameterMapping` diciendo que agregar un parámetro allá obliga a agregarlo
acá. Es débil, y está documentado que es débil.

**La guía dice lo que hoy falla.** Se agregó una séptima limitación
(`emptyWalletVariables`): Wallet a veces no entrega monto ni comercio, en ese
caso no se registra nada, y el aviso aparece en Atajos. Se documentaba el modo
de falla ya resuelto (emparejamiento de tarjeta) y se callaba el que sigue
abierto.

**El onboarding solo lo ven las instalaciones nuevas de verdad.**
`adoptOnboardingStateForExistingUser` corre tras cargar los datos: si la
bandera nunca se escribió **y** ya hay una tarjeta o un gasto, la da por vista.
La señal es tener datos, no un número de versión, porque no hay ninguno
guardado. Ante un error de lectura responde que no hay datos: mostrar el
onboarding de más molesta, saltárselo por un fallo transitorio deja a un
usuario nuevo sin la guía y sin forma obvia de encontrarla.

**Estructura:** `OnboardingFeature` es un paquete como cualquier otra feature,
sin importar otras features; `ContentView` inyecta como closures lo que cruza
fronteras (`onOpenCardSettings`, `onOpenShortcutsApp`). `ApplePayEnvironmentProbing`
vive en `LanaCore` (Foundation puro) y su implementación en el target de la
app, que es quien sabe de `UIApplication`.

## Consecuencias

**Bueno:**

- La guía ya no le enseña al usuario a armar el atajo roto, y le advierte del
  modo de falla que sigue abierto.
- Quien ya usa Lana no pierde su pantalla de inicio por una feature opcional.
- El aislamiento entre features quedó correcto y el paquete se integra como
  los demás.

**Malo / a vigilar:**

- **Nada impide que la guía y el intent se vuelvan a desincronizar.** Es
  exactamente el defecto que causó esto, y la única defensa nueva son dos
  comentarios. Si algún día el target de la app se puede probar (o si Apple
  permite un título no literal), el test que compare ambos lados es la
  corrección de verdad.
- `hasExistingData` hace una lectura de gastos de 5 años al arrancar, pero
  solo la primera vez que la bandera no existe. Es trabajo de más en un
  camino que corre una sola vez por instalación.
- La detección de "usuario existente" se apoya en tener datos. Alguien que
  instaló Lana, no capturó nada y actualiza, verá el onboarding — correcto por
  definición, pero es un caso que no se puede distinguir de una instalación
  nueva.
- Sigue abierto lo de ADR-0033: si Wallet simplemente no tiene monto ni
  comercio al momento del tap, esta guía enseña a configurar algo que no puede
  funcionar del todo, por más completa que esté. La limitación nueva lo dice,
  pero no lo resuelve.
