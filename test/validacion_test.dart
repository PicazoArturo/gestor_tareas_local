import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_tareas_local/data/tareas_repository.dart';

void main() {
  group('TareasRepository.validarTitulo', () {
    test('rechaza texto vacío, nulo o solo espacios/tabs/saltos', () {
      for (final valor in [null, '', '   ', '\t', '\n  \t']) {
        expect(
          () => TareasRepository.validarTitulo(valor),
          throwsA(isA<TituloInvalidoException>()),
          reason: 'valor: ${valor == null ? 'null' : '"$valor"'}',
        );
      }
    });

    test('recorta espacios al inicio y al final', () {
      expect(TareasRepository.validarTitulo('  Comprar pan  '), 'Comprar pan');
    });

    test('acepta exactamente la longitud máxima y rechaza una más', () {
      final maximo = 'a' * TareasRepository.longitudMaxima;
      expect(TareasRepository.validarTitulo(maximo), maximo);
      expect(
        () => TareasRepository.validarTitulo('${maximo}a'),
        throwsA(isA<TituloInvalidoException>()),
      );
    });
  });
}
