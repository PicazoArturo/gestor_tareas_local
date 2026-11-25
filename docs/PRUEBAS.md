# Comprobación técnica P1–P6

Fecha: 2026-11-24 · Flutter 3.47.7 · drift 2.35.4 · sqlite3 3.5.2 · macOS 26.6.1 (Apple Silicon)

"Reiniciar" significa **cerrar por completo** el proceso y volver a abrir la app. Un hot reload
o un hot restart no cuentan como prueba, porque el proceso no muere.

| ID | Acción | Web (Chrome 158, `localhost:8090`) | Móvil: Android (emulador API 37) | Escritorio: macOS 26.6 |
|---|---|---|---|---|
| P1 | 3 tareas, cerrar y abrir | ✅ Siguen las 3 (cerrando pestaña **y** Chrome completo) | ✅ Siguen las 3 tras `am force-stop` | ✅ Siguen las 3 tras Cmd+Q |
| P2 | Marcar completada y reiniciar | ✅ Conserva "Completada" | ✅ | ✅ |
| P3 | Editar título y reiniciar | ✅ Aparece el título nuevo | ✅ | ✅ |
| P4 | Eliminar y reiniciar | ✅ No reaparece | ✅ | ✅ (proceso terminado con `kill`) |
| P5 | Título vacío / solo espacios | ✅ No se registra, muestra "Escribe un título para la tarea." | ✅ | ✅ |
| P6 | Recargar y cerrar/abrir pestaña, mismo origen y perfil | ✅ Persisten | n/a | n/a |

## Detalle por plataforma

### Web
- Build `flutter build web`, servido en `http://127.0.0.1:8090` con `python3 -m http.server`.
- Chrome con un perfil fijo (`--user-data-dir`). Drift reportó
  `WasmStorageImplementation.sharedIndexedDb` (faltaban `SharedArrayBuffer` y workers dedicados
  dentro de SharedWorker porque no se sirvieron cabeceras COOP/COEP). En DevTools →
  Application → IndexedDB aparece la base `gestor_tareas`.
- Evidencias: `evidencias/web_1_tres_tareas_y_p5.png`, `evidencias/web_2_tras_cerrar_chrome.png`.

### Móvil: Android
- `flutter build apk --debug`, instalado en el AVD *Medium Phone API 37.0*.
- "Cerrar completamente" = `adb shell am force-stop mx.uaa.picazo.gestor_tareas_local`. Se
  comprobó con `pidof` que el proceso ya no existía y que al reabrir tenía un PID nuevo.
- Se leyó el archivo real con
  `adb exec-out run-as mx.uaa.picazo.gestor_tareas_local cat app_flutter/gestor_tareas.sqlite`
  y `sqlite3`: esquema `tareas` y filas `1|Comprar despensa|1`,
  `2|Estudiar para el examen de SQLite editada|0` (la 3 eliminada).
- Evidencias: `evidencias/android_1_tres_tareas_y_p5.png`, `evidencias/android_2_tras_force_stop.png`.

### Escritorio: macOS
- `flutter build macos --debug` con Xcode 16.3 (plugins por Swift Package Manager; no hizo falta
  CocoaPods).
- Base en el contenedor sandbox:
  `~/Library/Containers/mx.uaa.picazo.gestorTareasLocal/Data/Documents/gestor_tareas.sqlite`.
  `sqlite3` mostró `1|Comprar despensa|1` y `2|Estudiar Drift y SQLite (editada)|0`.
- La app se cerró con Cmd+Q (P1) y con `kill` (P4) antes de reabrirla.
- Evidencia: `evidencias/macos_tras_cerrar_app.jpg`.

## Plataformas previstas, no ejecutadas
- **iOS**: no se ejecutó (no había simulador iOS instalado). Usa el mismo camino nativo que macOS
  (`path_provider` + sqlite3 por build hooks), sin código específico.
- **Windows / Linux**: solo se compilan desde ese sistema operativo y no hay equipos disponibles.
  `flutter create` generó `windows/` y `linux/`, y `generated_plugins.cmake` ya incluye los plugins.
