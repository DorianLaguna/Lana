# ADR-0031: Separar el alias visible de una tarjeta del texto usado para emparejarla con Wallet

- **Estado:** Aceptada
- **Fecha:** 2026-09-01

## Contexto

ADR-0019 decidió que `Card.bestMatch(for:in:)` empareja el texto que entrega el
trigger de Wallet contra el `alias` de la tarjeta (como substring, si los
últimos 4 dígitos no resuelven). Ese ADR ya anotó el costo en su sección de
consecuencias: *"si el nombre en Wallet no se parece al alias en Lana... el
atajo falla en cada ejecución hasta que el usuario ajuste el alias"*.

En uso real (2026-09-01) ese costo se manifestó de la forma más incómoda
posible: la tarjeta es Bancomer, pero Wallet la nombra "TDC Azul" — un nombre
que el usuario no quiere ver en ningún otro lado de la app (dashboard, picker
de método de pago, captura por voz). Usar un único `alias` obliga a elegir
entre dos cosas que en este caso no coinciden: el nombre corto que el usuario
quiere decir/ver ("Bancomer") y el texto que hace que el match con Wallet
funcione ("TDC Azul").

Dos alternativas reales, cada una con su tradeoff:

- **Alternativa descartada:** mantener un solo campo, y documentar que el
  usuario debe elegir el alias en función de cómo nombra Wallet la tarjeta
  (sacrificando el nombre que preferiría usar/decir en voz). Más simple —
  cero cambio de modelo — pero le pide al usuario memorizar y decir en voz
  algo que no es como él piensa naturalmente en la tarjeta, justo lo opuesto
  al principio "gana la opción que quita fricción de la captura"
  (Docs/CLAUDE.md).
- **Elegida:** agregar un segundo campo opcional, `walletMatchHint`, usado
  únicamente por `Card.bestMatch` cuando está presente, sin aparecer en
  ningún otro lugar de la UI. El `alias` queda libre para ser lo que el
  usuario prefiera decir/ver.

## Decisión

`Card` gana un campo `walletMatchHint: String?` (`LanaCore/Models/Card.swift`).
`Card.bestMatch` usa `walletMatchHint ?? alias` como el texto contra el que
compara el substring — la prioridad de los últimos 4 dígitos sobre el alias no
cambia, sigue ganando siempre que resuelva a una sola tarjeta.

El campo es opcional y vive solo en el formulario de tarjeta
(`AddCardView`/`AddCardModel`, sección aparte con nota explicando su
propósito) — nunca se muestra en dashboard, picker de método de pago, ni se
ofrece como algo que decir en captura por voz. Cuando está vacío, el
comportamiento es idéntico al de antes de este ADR (match por alias).

El mensaje de `AddTransactionIntentError.cardNotFound` se actualiza para
mencionar el nuevo campo junto al alias y los últimos 4 dígitos, ya que ahora
hay tres lugares que revisar si el atajo no encuentra la tarjeta.

## Consecuencias

- Un campo más en el formulario de tarjeta que la mayoría de los usuarios
  nunca necesita tocar (solo aplica cuando el alias que quieren usar no
  aparece dentro del texto que Wallet reporta) — costo de superficie de UI
  pequeño pero real, mitigado con la nota explicativa en el propio formulario.
- `Card` gana una columna más en Core Data (`walletMatchHint`, opcional,
  mismo patrón que `kind`/`colorHex` al agregarse después — ADR-0014).
  Migración liviana: el modelo se construye en código
  (`LanaManagedObjectModel.swift`), no hay `.xcdatamodeld` versionado que
  migrar, y todas las columnas ya son opcionales por diseño.
- Si en el uso real la mayoría de los usuarios termina llenando este campo
  (en vez de ser la excepción), es señal de que el match por texto contra
  Wallet es más frágil de lo que ADR-0019 asumió, y valdría la pena
  revisitar esa decisión completa (el picker fijo que ADR-0019 descartó)
  en vez de seguir agregando campos de ajuste.
