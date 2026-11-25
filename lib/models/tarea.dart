/// Modelo que usa la interfaz. Es independiente de Drift: el repositorio
/// convierte cada fila de la tabla `tareas` en un objeto [Tarea].
class Tarea {
  final int id;
  final String titulo;
  final bool completada;

  const Tarea({
    required this.id,
    required this.titulo,
    required this.completada,
  });
}
