import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/utils/ip_input_formatter.dart';

String _type(String previous, String next) {
  final formatter = IpAddressInputFormatter();
  return formatter
      .formatEditUpdate(
        TextEditingValue(text: previous),
        TextEditingValue(text: next),
      )
      .text;
}

void main() {
  test('adiciona ponto automaticamente após 3 dígitos', () {
    expect(_type('19', '192'), '192.');
    expect(_type('192.16', '192.168'), '192.168.');
  });

  test('não adiciona ponto após o quarto octeto', () {
    expect(_type('192.168.1.15', '192.168.1.155'), '192.168.1.155');
  });

  test('limita octetos a 255 e ignora caracteres inválidos', () {
    expect(_type('29', '299'), '255.');
    expect(_type('', 'a1b'), '1');
  });

  test('apagar não reinsere o ponto automático', () {
    expect(_type('192.1', '192.'), '192.');
    expect(_type('192.', '192'), '192');
  });
}
