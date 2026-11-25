import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_tareas_local/data/database.dart';
import 'package:gestor_tareas_local/data/tareas_repository.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('CRUD sobre SQLite (en memoria)', () {
    late TareasRepository repo;

    setUp(() => repo = TareasRepository(AppDatabase(NativeDatabase.memory())));
    tearDown(() => repo.cerrar());

    test('INSERT asigna ids únicos y la tarea nace pendiente', () async {
      final id1 = await repo.agregar('Uno');
      final id2 = await repo.agregar('Dos');
      expect(id1, isNot(id2));

      final tareas = await repo.obtenerTareas();
      expect(tareas.map((t) => t.titulo), ['Uno', 'Dos']);
      expect(tareas.every((t) => !t.completada), isTrue);
    });

    test('un título inválido no llega a la base', () async {
      await expectLater(
        repo.agregar('   '),
        throwsA(isA<TituloInvalidoException>()),
      );
      expect(await repo.obtenerTareas(), isEmpty);
    });

    test('UPDATE de título y de estado; DELETE por id', () async {
      final id = await repo.agregar('Borrador');
      final otro = await repo.agregar('Se queda');

      await repo.editarTitulo(id, '  Final  ');
      await repo.cambiarEstado(id, true);
      var tarea = (await repo.obtenerTareas()).firstWhere((t) => t.id == id);
      expect(tarea.titulo, 'Final');
      expect(tarea.completada, isTrue);

      await repo.cambiarEstado(id, false);
      tarea = (await repo.obtenerTareas()).firstWhere((t) => t.id == id);
      expect(tarea.completada, isFalse);

      await repo.eliminar(id);
      expect((await repo.obtenerTareas()).map((t) => t.id), [otro]);
    });

    test(
      'operar sobre un id inexistente lanza TareaNoEncontradaException',
      () async {
        expect(repo.eliminar(999), throwsA(isA<TareaNoEncontradaException>()));
        expect(
          repo.cambiarEstado(999, true),
          throwsA(isA<TareaNoEncontradaException>()),
        );
        expect(
          repo.editarTitulo(999, 'x'),
          throwsA(isA<TareaNoEncontradaException>()),
        );
      },
    );

    test('el Stream emite de nuevo después de cada escritura', () async {
      final emisiones = repo.observarTareas().map((l) => l.length);
      final esperado = expectLater(emisiones, emitsInOrder([0, 1, 2, 1]));
      // Pequeñas pausas para que cada escritura produzca su propia emisión.
      Future<void> pausa() =>
          Future<void>.delayed(const Duration(milliseconds: 20));
      await pausa();
      final id = await repo.agregar('A');
      await pausa();
      await repo.agregar('B');
      await pausa();
      await repo.eliminar(id);
      await esperado;
    });
  });

  test(
    'los datos sobreviven a cerrar y reabrir el archivo SQLite (P1–P4)',
    () async {
      final dir = await Directory.systemTemp.createTemp('gestor_tareas_test');
      final archivo = File('${dir.path}/gestor_tareas.sqlite');
      addTearDown(() => dir.delete(recursive: true));

      // Primera "ejecución" de la app.
      var repo = TareasRepository(AppDatabase(NativeDatabase(archivo)));
      final a = await repo.agregar('Tarea A');
      final b = await repo.agregar('Tarea B');
      await repo.agregar('Tarea C');
      await repo.cambiarEstado(a, true);
      await repo.editarTitulo(b, 'Tarea B editada');
      await repo.cerrar();

      // Segunda "ejecución": nueva conexión al mismo archivo.
      repo = TareasRepository(AppDatabase(NativeDatabase(archivo)));
      var tareas = await repo.obtenerTareas();
      expect(tareas.map((t) => t.titulo), [
        'Tarea A',
        'Tarea B editada',
        'Tarea C',
      ]);
      expect(tareas.first.completada, isTrue);
      await repo.eliminar(a);
      await repo.cerrar();

      // Tercera "ejecución": la tarea eliminada no reaparece.
      repo = TareasRepository(AppDatabase(NativeDatabase(archivo)));
      tareas = await repo.obtenerTareas();
      expect(tareas.map((t) => t.titulo), ['Tarea B editada', 'Tarea C']);
      await repo.cerrar();
    },
  );
}
