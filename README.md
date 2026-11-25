# Gestor de tareas local con SQLite (Flutter + Drift)

Práctica individual de **Programación de Dispositivos Móviles (UAA, 7.º semestre)**.
Es una app Flutter que guarda tareas en una base **SQLite local**: sin servidor, sin MySQL y sin
HTTP. El mismo código corre en Android, iOS, Windows, Linux, macOS y web.

## Tecnología de persistencia elegida

| Paquete | Versión | Para qué |
|---|---|---|
| `drift` | 2.35.4 | ORM/consultas tipadas sobre SQLite y consultas reactivas (`Stream`) |
| `drift_flutter` | 0.3.1 | `driftDatabase()`: abre la base adecuada en cada plataforma |
| `sqlite3` | 3.5.2 (transitiva) | Motor SQLite. En nativo se integra con *build hooks*; en web usa `sqlite3.wasm` |
| `drift_dev` + `build_runner` | 2.35.3 / 2.17.1 (dev) | Generan `database.g.dart` a partir de la definición de la tabla |

**¿Por qué Drift?** `sqflite` no soporta escritorio ni web sin paquetes extra. Drift + drift_flutter
da una sola API para las 6 plataformas, revisa las consultas en tiempo de compilación y ofrece
consultas `watch()`, así la UI se actualiza sola después de cada escritura.

## Diseño de la tabla

```sql
CREATE TABLE tareas (
  id         INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, -- identificador único
  titulo     TEXT    NOT NULL,                            -- 1..120 caracteres (validado)
  completada INTEGER NOT NULL DEFAULT 0 CHECK (completada IN (0, 1)) -- bool
);
```

- Cada registro se identifica por `id`, que SQLite asigna con `AUTOINCREMENT`. Los ids no se
  reutilizan aunque se borren tareas.
- SQLite no tiene tipo booleano. Drift guarda `bool` como `INTEGER` 0/1 y añade el `CHECK`.

## Estructura

```
lib/
├── main.dart                    # Abre una sola conexión y la cierra al desmontar la app
├── models/tarea.dart            # Modelo de la UI (independiente de Drift)
├── data/
│   ├── database.dart            # Tabla Tareas + AppDatabase (INSERT/SELECT/UPDATE/DELETE)
│   ├── database.g.dart          # Generado por build_runner (se versiona)
│   └── tareas_repository.dart   # Validación, conversión fila→modelo, errores legibles
└── screens/tareas_page.dart     # UI: se suscribe al Stream en initState (nada de SQL en build)
web/
├── sqlite3.wasm                 # SQLite compilado a WebAssembly (release sqlite3-3.5.2)
└── drift_worker.js              # Worker de Drift (incluido en el paquete drift 2.35.4)
test/
├── widget_test.dart             # UI + SQLite en memoria: alta, P5, marcar/editar/eliminar
├── validacion_test.dart         # Reglas del título
└── tareas_repository_test.dart  # CRUD, Stream reactivo y persistencia en archivo (cerrar/reabrir)
```

### ¿Dónde queda la base?

| Plataforma | Ubicación |
|---|---|
| Android | `/data/data/mx.uaa.picazo.gestor_tareas_local/app_flutter/gestor_tareas.sqlite` |
| macOS | `~/Library/Containers/mx.uaa.picazo.gestorTareasLocal/Data/Documents/gestor_tareas.sqlite` |
| iOS | Carpeta *Documents* del sandbox de la app → `gestor_tareas.sqlite` |
| Windows / Linux | Directorio de documentos que da `path_provider` → `gestor_tareas.sqlite` |
| Web | IndexedDB u OPFS del origen (`gestor_tareas`). Drift elige según el navegador |

## Cómo ejecutarlo

Requisitos: Flutter 3.47.x estable (probado con 3.47.7 / Dart 3.13.5).

```bash
git clone https://github.com/PicazoArturo/gestor_tareas_local.git
cd gestor_tareas_local
flutter pub get
flutter analyze
flutter test
```

`database.g.dart` ya viene en el repo. Si cambias la tabla, regenéralo:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Web (P6 reproducible)

La persistencia web depende del **origen** (esquema + host + **puerto**) y del **perfil** del
navegador. `flutter run -d chrome` usa un puerto aleatorio y un perfil temporal nuevo en cada
ejecución, así que parece que "se pierden" los datos. Para probar P6 usa un puerto fijo:

```bash
flutter run -d chrome --web-port 8090
# o compilado:
flutter build web && cd build/web && python3 -m http.server 8090
# y abrir http://localhost:8090 en un Chrome normal
```

### Android / escritorio

```bash
flutter devices
flutter run -d emulator-5554     # Android
flutter run -d macos             # escritorio (requiere Xcode completo)
```

Si `xcode-select -p` apunta a `/Library/Developer/CommandLineTools`, se puede compilar sin
cambiar la configuración global:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer flutter run -d macos
```

## Pruebas automatizadas (`flutter test`, 13 casos)

- **validacion_test.dart**: rechaza `null`, vacío y solo espacios/tabs/saltos. Recorta espacios.
  Prueba el límite de 120 caracteres.
- **tareas_repository_test.dart**: INSERT con ids únicos; un título inválido no llega a la base;
  UPDATE de título y estado; DELETE por id; ids inexistentes lanzan error; el `Stream` emite
  después de cada escritura; **persistencia real en archivo**: escribe, cierra, reabre el mismo
  `.sqlite` y comprueba P1–P4.
- **widget_test.dart**: la pantalla abre; agregar desde la UI guarda en SQLite; P5 desde la UI;
  marcar, editar (diálogo) y eliminar desde la UI actualizan la base.

## Comprobación técnica (P1–P6)

| Plataforma | Resultado |
|---|---|
| Web (Chrome) | P1–P6 ✅ |
| Móvil (Android, emulador API 37) | P1–P5 ✅ |
| Escritorio (macOS 26.6) | P1–P5 ✅ |
| iOS, Windows, Linux | Previstas (mismo código), no ejecutadas |
