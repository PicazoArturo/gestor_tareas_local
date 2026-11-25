import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// Tabla `tareas` en SQLite.
///
/// SQL equivalente que genera Drift:
/// ```sql
/// CREATE TABLE tareas (
///   id         INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
///   titulo     TEXT    NOT NULL,
///   completada INTEGER NOT NULL DEFAULT 0 CHECK (completada IN (0, 1))
/// );
/// ```
/// SQLite no tiene tipo booleano: Drift guarda `bool` como INTEGER 0/1.
/// `withLength(1, 120)` lo verifica Drift en Dart antes de cada INSERT/UPDATE.
@DataClassName('TareaFila')
class Tareas extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get titulo => text().withLength(min: 1, max: 120)();
  BoolColumn get completada => boolean().withDefault(const Constant(false))();
}

/// Base de datos local de la app. Contiene únicamente SQL; la validación de
/// entradas y la conversión al modelo de la UI viven en `TareasRepository`.
@DriftDatabase(tables: [Tareas])
class AppDatabase extends _$AppDatabase {
  /// El parámetro opcional permite inyectar una base en memoria en las pruebas.
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _abrirConexion());

  @override
  int get schemaVersion => 1;

  /// Abre `gestor_tareas.sqlite` según la plataforma:
  /// - Android/iOS/macOS/Windows/Linux: archivo en el directorio de documentos
  ///   de la app (`getApplicationDocumentsDirectory()` de path_provider).
  /// - Web: SQLite compilado a WebAssembly (`web/sqlite3.wasm`) que guarda el
  ///   archivo en OPFS o IndexedDB; `web/drift_worker.js` lo comparte entre pestañas.
  static QueryExecutor _abrirConexion() {
    return driftDatabase(
      name: 'gestor_tareas',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  }

  /// SELECT * FROM tareas ORDER BY id; como Stream: se vuelve a emitir cada
  /// vez que un INSERT/UPDATE/DELETE modifica la tabla.
  Stream<List<TareaFila>> observarTareas() {
    return (select(tareas)..orderBy([(t) => OrderingTerm.asc(t.id)])).watch();
  }

  Future<List<TareaFila>> obtenerTareas() {
    return (select(tareas)..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
  }

  /// INSERT INTO tareas (titulo) VALUES (?); devuelve el id generado.
  Future<int> insertarTarea(String titulo) {
    return into(tareas).insert(TareasCompanion.insert(titulo: titulo));
  }

  /// UPDATE tareas SET titulo = ? WHERE id = ?; devuelve filas afectadas.
  Future<int> actualizarTitulo(int id, String titulo) {
    return (update(tareas)..where((t) => t.id.equals(id))).write(
      TareasCompanion(titulo: Value(titulo)),
    );
  }

  /// UPDATE tareas SET completada = ? WHERE id = ?
  Future<int> actualizarCompletada(int id, bool completada) {
    return (update(tareas)..where((t) => t.id.equals(id))).write(
      TareasCompanion(completada: Value(completada)),
    );
  }

  /// DELETE FROM tareas WHERE id = ?
  Future<int> eliminarTarea(int id) {
    return (delete(tareas)..where((t) => t.id.equals(id))).go();
  }
}
