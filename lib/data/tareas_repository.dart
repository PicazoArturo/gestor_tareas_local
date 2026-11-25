import '../models/tarea.dart';
import 'database.dart';

/// Error de validación con un mensaje listo para mostrarse al usuario.
class TituloInvalidoException implements Exception {
  final String mensaje;
  const TituloInvalidoException(this.mensaje);

  @override
  String toString() => mensaje;
}

/// La tarea ya no existe en la base (p. ej. se borró en otra pestaña).
class TareaNoEncontradaException implements Exception {
  final int id;
  const TareaNoEncontradaException(this.id);

  @override
  String toString() => 'La tarea $id ya no existe.';
}

/// Intermediario entre la UI y la base de datos: valida entradas, convierte
/// filas de SQLite al modelo [Tarea] y verifica que las escrituras apliquen.
class TareasRepository {
  static const int longitudMaxima = 120;

  final AppDatabase _db;

  TareasRepository(this._db);

  /// Quita espacios al inicio y al final y valida el título.
  /// Lanza [TituloInvalidoException] si queda vacío o es demasiado largo.
  static String validarTitulo(String? titulo) {
    final limpio = (titulo ?? '').trim();
    if (limpio.isEmpty) {
      throw const TituloInvalidoException('Escribe un título para la tarea.');
    }
    if (limpio.length > longitudMaxima) {
      throw const TituloInvalidoException(
        'El título no puede pasar de $longitudMaxima caracteres.',
      );
    }
    return limpio;
  }

  /// Lista reactiva: emite de nuevo después de cada escritura.
  Stream<List<Tarea>> observarTareas() =>
      _db.observarTareas().map((filas) => filas.map(_aModelo).toList());

  Future<List<Tarea>> obtenerTareas() async =>
      (await _db.obtenerTareas()).map(_aModelo).toList();

  Future<int> agregar(String titulo) async {
    // async: así un título inválido llega como Future con error, no como
    // excepción síncrona.
    return _db.insertarTarea(validarTitulo(titulo));
  }

  Future<void> editarTitulo(int id, String titulo) async {
    final filas = await _db.actualizarTitulo(id, validarTitulo(titulo));
    if (filas == 0) throw TareaNoEncontradaException(id);
  }

  Future<void> cambiarEstado(int id, bool completada) async {
    final filas = await _db.actualizarCompletada(id, completada);
    if (filas == 0) throw TareaNoEncontradaException(id);
  }

  Future<void> eliminar(int id) async {
    final filas = await _db.eliminarTarea(id);
    if (filas == 0) throw TareaNoEncontradaException(id);
  }

  /// Cierra la conexión a SQLite (libera el archivo / el worker web).
  Future<void> cerrar() => _db.close();

  static Tarea _aModelo(TareaFila fila) =>
      Tarea(id: fila.id, titulo: fila.titulo, completada: fila.completada);
}
