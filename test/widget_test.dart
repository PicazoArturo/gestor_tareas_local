import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_tareas_local/data/database.dart';
import 'package:gestor_tareas_local/data/tareas_repository.dart';
import 'package:gestor_tareas_local/main.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late TareasRepository repo;

  /// Cada prueba usa una base SQLite real en memoria. Las operaciones de
  /// NativeDatabase en memoria se resuelven con microtareas, así que basta con
  /// `pump()` para que avancen dentro del reloj falso de testWidgets.
  void testApp(String descripcion, Future<void> Function(WidgetTester) cuerpo) {
    testWidgets(descripcion, (tester) async {
      repo = TareasRepository(
        AppDatabase(
          DatabaseConnection(
            NativeDatabase.memory(),
            closeStreamsSynchronously: true,
          ),
        ),
      );
      await cuerpo(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      final cierre = repo.cerrar();
      await tester.pump();
      await cierre;
    });
  }

  /// Espera un Future del repositorio dejando correr las microtareas.
  Future<T> resolver<T>(WidgetTester tester, Future<T> futuro) async {
    await tester.pump();
    await tester.pump();
    return futuro;
  }

  Future<void> abrirApp(WidgetTester tester) async {
    await tester.pumpWidget(GestorTareasApp(repositorio: repo));
    await tester.pump();
    await tester.pump();
  }

  testApp('La pantalla inicial se muestra sin errores', (tester) async {
    await abrirApp(tester);
    expect(find.text('Gestor de tareas'), findsOneWidget);
    expect(find.text('Agregar tarea'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Todavía no hay tareas guardadas'), findsOneWidget);
  });

  testApp('Agregar desde la UI guarda en SQLite y aparece en la lista', (
    tester,
  ) async {
    await abrirApp(tester);

    await tester.enterText(find.byType(TextField), '  Estudiar Drift  ');
    await tester.tap(find.text('Agregar tarea'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Estudiar Drift'), findsOneWidget);
    final enBase = await resolver(tester, repo.obtenerTareas());
    expect(enBase.single.titulo, 'Estudiar Drift');
  });

  testApp('Un título con solo espacios no se registra (P5)', (tester) async {
    await abrirApp(tester);

    await tester.enterText(find.byType(TextField), '    ');
    await tester.tap(find.text('Agregar tarea'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Escribe un título para la tarea.'), findsOneWidget);
    expect(await resolver(tester, repo.obtenerTareas()), isEmpty);
  });

  testApp('Marcar, editar y eliminar desde la UI actualiza la base', (
    tester,
  ) async {
    await resolver(tester, repo.agregar('Tarea original'));
    await abrirApp(tester);
    expect(find.text('Tarea original'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.pump();
    final marcada = await resolver(tester, repo.obtenerTareas());
    expect(marcada.single.completada, isTrue);

    await tester.tap(find.byTooltip('Editar'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'Tarea editada',
    );
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Tarea editada'), findsOneWidget);

    await tester.tap(find.byTooltip('Eliminar'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Todavía no hay tareas guardadas'), findsOneWidget);
    expect(await resolver(tester, repo.obtenerTareas()), isEmpty);
    // Deja que el SnackBar termine su animación.
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });
}
