import 'package:flutter/services.dart';

class IpAddressInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final isDeleting = newValue.text.length < oldValue.text.length;

    var raw = newValue.text.replaceAll(RegExp(r'[^0-9.]'), '');
    raw = raw.replaceAll(RegExp(r'\.{2,}'), '.');
    if (raw.startsWith('.')) raw = raw.substring(1);

    final octets = <String>[];
    for (final part in raw.split('.').take(4)) {
      var octet = part.length > 3 ? part.substring(0, 3) : part;
      if (octet.isNotEmpty && int.parse(octet) > 255) octet = '255';
      octets.add(octet);
    }

    var text = octets.join('.');
    if (!isDeleting && octets.length < 4 && octets.last.length == 3) {
      text += '.';
    }

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
