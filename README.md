# Descargas de GC Digital

Instaladores de las apps de [GC Digital](https://gc-digital.mx). Aquí no hay código: cada día el
workflow **Publicar descargas** toma la última versión de cada app y la deja en el release
[«ultima»](../../releases/tag/ultima) con un nombre fijo.

| App | Archivo | Enlace corto |
|---|---|---|
| Copal (Android) | `Copal.apk` | gc-digital.mx/descargar/copal |
| Costeo Artesanal (Android) | `CosteoArtesanal.apk` | gc-digital.mx/descargar/costeo |
| Ajolote Fiscal (Windows) | `AjoloteFiscal-Windows.exe` | gc-digital.mx/descargar/ajolote-windows |
| Ajolote Fiscal (Mac M1 o más nueva) | `AjoloteFiscal-Mac-Apple.dmg` | gc-digital.mx/descargar/ajolote-mac |
| Ajolote Fiscal (Mac Intel) | `AjoloteFiscal-Mac-Intel.dmg` | gc-digital.mx/descargar/ajolote-mac-intel |

Cada app trae 15 días de prueba; después se activa con una clave. Precios y compra en
[gc-digital.mx/comprar](https://gc-digital.mx/comprar).

Para publicar a mano (por ejemplo, justo después de armar una versión): Actions › Publicar descargas › Run workflow.
Necesita los secretos `EXPO_TOKEN` y `DESCARGAS_TOKEN` (solo lectura de los repositorios de las apps).
