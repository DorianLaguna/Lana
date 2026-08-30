# ADR-0028: Los ingresos viven en la lista, el split proporcional es el default, y el usuario se ve como "Yo"

- **Estado:** Aceptada
- **Fecha:** 2026-08-28

## Contexto

Tres cosas que el usuario pidió juntas, después de usar Compartido de
verdad:

1. "Quiero que como se divide sea por default el de proporcional, y pues
   ahí ya debería tener como los datos de cómo se divide el gasto." — El
   split proporcional existía desde ADR-0007, pero exigía teclear la
   proporción **en cada gasto**. Nadie hace eso: la proporción es un dato
   estable de la relación (cuánto gana cada quien), no del gasto.
2. "No veo forma de editar la lista y los nombres." — Cierto: `SharedList`
   se creaba y ya. Un typo en un nombre era permanente.
3. "Cuando yo digo que soy una persona, entonces debería aparecer como
   'yo' o algo así, no con mi nombre." — La identidad del dispositivo ya
   existía (ADR-0022) pero solo se usaba para calcular montos, nunca para
   mostrar.

## Decisión

**1. `Participant.monthlyIncome: Decimal?` — el dato vive en la lista.**

`SharedList` gana dos propiedades derivadas:
`proportionalSplitFromIncomes` (normaliza los ingresos a fracciones que
suman exactamente 1) y `preferredSplit` (el proporcional si está
disponible, si no el `defaultSplit` guardado). La captura de un gasto nuevo
arranca con `preferredSplit` ya resuelto.

`nil` es válido y significa "no capturado": si alguien del roster no tiene
ingreso, o suman 0, no hay proporcional y se cae a partes iguales. No se
adivina una proporción.

Dos detalles que importan:

- La normalización le da el residuo del redondeo al último participante por
  orden de `ParticipantID`, igual que `SplitRule.distribute`. Sin eso, tres
  ingresos iguales producen fracciones que suman `0.999999` y
  `portions(of:)` lanza `sharesDontSumToOne` — el split se ve bien y truena
  al guardar. Hay un test justamente de ese caso.
- `monthlyIncome` es `Optional` a propósito: `Participant` se serializa
  como JSON dentro de `CDSharedList.participantsData`, y el `Codable`
  sintetizado usa `decodeIfPresent` para opcionales, así que las listas
  creadas antes de esto siguen decodificando sin migración.

Cambiar un ingreso aplica **hacia adelante**: cada gasto ya registrado
tiene su proporción congelada en el evento (ADR-0007), y nada la recalcula.

**2. `EditSharedListView` — editar nombre, roster e ingresos.**

Un tercer botón en el toolbar de la lista. Deja renombrar la lista, renombrar
participantes, capturar/cambiar ingresos, agregar participantes y cambiar
quién soy yo.

**No deja quitar participantes, a propósito.** Un participante puede tener
gastos y liquidaciones a su nombre; quitarlo del roster no borra esos
eventos, solo dejaría su saldo sin nombre que mostrar
(`SharedListDetailModel.load` descarta los balances cuyo `Participant` no
resuelve). Eso es perder dinero de vista en silencio, que es exactamente lo
que Docs/CLAUDE.md prohíbe. Renombrar sí conserva el `ParticipantID`, así
que nunca reasigna gastos a otra persona.

**3. `displayName(for:)` — "Yo" en vez del nombre propio.**

`SharedListDetailModel` guarda `viewerParticipantID` y expone
`displayName(for:)`, que devuelve "Yo" cuando coincide. Lo usan saldos,
deudas, el detalle de deuda, la fila de gasto, el picker de pagador de la
captura y el del editor del Dashboard. Es **solo presentación**: el roster
sigue guardando el nombre real, que es lo que la otra persona ve en su
dispositivo.

El pagador de un gasto nuevo también arranca en "yo" cuando la identidad
está marcada — es quien captura, el caso abrumadoramente común.

## Consecuencias

**Bueno:**

- Capturar un gasto compartido en una pareja con ingresos distintos ya no
  pide teclear la proporción: sale de la lista, resuelta.
- Un typo en un nombre deja de ser permanente.
- La lista se lee como la lee su dueño ("Yo debe $246") en vez de obligar
  a traducir el propio nombre mentalmente.

**Malo / a vigilar:**

- El ingreso es un solo número por persona, sin historial ni fecha. Si
  alguien cambia de sueldo, el proporcional de los gastos nuevos cambia y
  no queda registro de cuándo — solo se puede reconstruir mirando las
  proporciones congeladas de cada gasto. Suficiente para v1; si hace falta
  auditarlo, el ingreso tendría que volverse un evento más.
- Guardar un ingreso en el roster significa que **viaja al otro
  participante** cuando la lista se comparte por CKShare: `participants`
  es parte de `CDSharedList`, que es justo lo que se mueve a la zona
  compartida (ADR-0020). Quien comparte una lista comparte cuánto gana
  cada quien. Es coherente con para qué sirve el dato (dividir
  proporcionalmente entre ambos, los dos necesitan saberlo), pero no está
  dicho en ningún lado de la UI. Si eso incomoda, el ingreso tendría que
  moverse a una entidad privada sin relación, como se hizo con
  `CDSharedListViewerPreference` (ADR-0022).
- No se pueden quitar participantes, ni siquiera uno recién agregado por
  error sin ningún gasto. La regla es conservadora de más; afinarla pide
  saber si ese participante aparece en algún evento, que hoy el modelo de
  edición no consulta.
- "Yo" se resuelve por lista. Un mismo `Participant` en dos listas puede
  verse como "Yo" en una y con su nombre en la otra si solo se marcó la
  identidad en una — correcto, pero puede desconcertar.
