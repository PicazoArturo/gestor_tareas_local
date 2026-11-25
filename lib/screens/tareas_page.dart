import 'dart:async';

import 'package:flutter/material.dart';

import '../data/tareas_repository.dart';
import '../models/tarea.dart';

/// Pantalla principal. No consulta SQLite dentro de build(): se suscribe una
/// sola vez (initState) al Stream del repositorio y build() solo pinta [_tareas].
class TareasPage extends StatefulWidget {
  final TareasRepository repositorio;

  const TareasPage({super.key, required this.repositorio});

  @override
  State<TareasPage> createState() => _TareasPageState();
}

class _TareasPageState extends State<TareasPage> {
  final TextEditingController _tituloController = TextEditingController();

  StreamSubscription<List<Tarea>>? _suscripcion;
  List<Tarea> _tareas = [];
  bool _cargando = true;
  String? _errorCarga;

  TareasRepository get _repo => widget.repositorio;

  @override
  void initState() {
    super.initState();
    _suscribirse();
  }

  void _suscribirse() {
    _suscripcion?.cancel();
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });
    _suscripcion = _repo.observarTareas().listen(
      (tareas) {
        if (!mounted) return;
        setState(() {
          _tareas = tareas;
          _cargando = false;
          _errorCarga = null;
        });
      },
      onError: (Object error) {
        debugPrint('Error al leer tareas: $error');
        if (!mounted) return;
        setState(() {
          _cargando = false;
          _errorCarga = 'No se pudo abrir la base de datos local.';
        });
      },
    );
  }

  /// Ejecuta una escritura y traduce cualquier excepción a un mensaje legible.
  /// La lista se actualiza sola gracias al Stream; no hace falta recargar.
  Future<bool> _ejecutar(Future<void> Function() operacion) async {
    try {
      await operacion();
      return true;
    } on TituloInvalidoException catch (e) {
      _mostrarMensaje(e.mensaje);
    } on TareaNoEncontradaException catch (e) {
      _mostrarMensaje(e.toString());
    } catch (e) {
      debugPrint('Error de almacenamiento: $e');
      _mostrarMensaje('No se pudo guardar el cambio. Inténtalo de nuevo.');
    }
    return false;
  }

  Future<void> _agregarTarea() async {
    final ok = await _ejecutar(() => _repo.agregar(_tituloController.text));
    if (ok) _tituloController.clear();
  }

  Future<void> _alternarCompletada(Tarea tarea, bool completada) async {
    await _ejecutar(() => _repo.cambiarEstado(tarea.id, completada));
  }

  Future<void> _editarTarea(Tarea tarea) async {
    final nuevoTitulo = await showDialog<String>(
      context: context,
      builder: (_) => _DialogoEditar(tituloInicial: tarea.titulo),
    );
    if (nuevoTitulo == null || nuevoTitulo.trim() == tarea.titulo) return;
    await _ejecutar(() => _repo.editarTitulo(tarea.id, nuevoTitulo));
  }

  Future<void> _eliminarTarea(Tarea tarea) async {
    final ok = await _ejecutar(() => _repo.eliminar(tarea.id));
    if (ok) _mostrarMensaje('Tarea "${tarea.titulo}" eliminada');
  }

  void _mostrarMensaje(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  void dispose() {
    _suscripcion?.cancel();
    _tituloController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestor de tareas')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _tituloController,
              maxLength: TareasRepository.longitudMaxima,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _agregarTarea(),
              decoration: const InputDecoration(
                labelText: 'Nueva tarea',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _agregarTarea,
              icon: const Icon(Icons.add),
              label: const Text('Agregar tarea'),
            ),
            const SizedBox(height: 12),
            const Text('Mis tareas', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Expanded(child: _contenido()),
          ],
        ),
      ),
    );
  }

  Widget _contenido() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorCarga != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorCarga!),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _suscribirse,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    if (_tareas.isEmpty) {
      return const Center(child: Text('Todavía no hay tareas guardadas'));
    }
    return ListView.builder(
      itemCount: _tareas.length,
      itemBuilder: (context, index) {
        final tarea = _tareas[index];
        return Card(
          child: ListTile(
            leading: Checkbox(
              value: tarea.completada,
              onChanged: (valor) {
                if (valor != null) _alternarCompletada(tarea, valor);
              },
            ),
            title: Text(
              tarea.titulo,
              style: tarea.completada
                  ? const TextStyle(decoration: TextDecoration.lineThrough)
                  : null,
            ),
            subtitle: Text(
              'ID: ${tarea.id} · ${tarea.completada ? 'Completada' : 'Pendiente'}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Editar',
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editarTarea(tarea),
                ),
                IconButton(
                  tooltip: 'Eliminar',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _eliminarTarea(tarea),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Diálogo para editar el título. Valida antes de cerrar para no enviar
/// títulos vacíos a la base de datos.
class _DialogoEditar extends StatefulWidget {
  final String tituloInicial;

  const _DialogoEditar({required this.tituloInicial});

  @override
  State<_DialogoEditar> createState() => _DialogoEditarState();
}

class _DialogoEditarState extends State<_DialogoEditar> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.tituloInicial,
  );
  String? _error;

  void _guardar() {
    try {
      Navigator.of(context)
          .pop(TareasRepository.validarTitulo(_controller.text));
    } on TituloInvalidoException catch (e) {
      setState(() => _error = e.mensaje);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar tarea'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: TareasRepository.longitudMaxima,
        onSubmitted: (_) => _guardar(),
        decoration: InputDecoration(labelText: 'Título', errorText: _error),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }
}
