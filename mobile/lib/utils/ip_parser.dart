class ParsedHostPort {
  final String ip;
  final String? port;

  const ParsedHostPort({required this.ip, this.port});
}

class IpParser {
  /// Extrai IP e porta de formatos como `192.168.1.155`, `192.168.1.155:3000` ou `http://192.168.1.155:3000`
  static ParsedHostPort? parse(String rawInput) {
    final raw = rawInput.trim();
    if (raw.isEmpty) return null;

    final cleaned = raw.replaceAll(RegExp(r'^https?://'), '');
    final parts = cleaned.split(':');
    final ipPart = parts[0].replaceAll(RegExp(r'[^0-9.]'), '');
    if (ipPart.isEmpty) return null;

    String? validPort;
    if (parts.length > 1) {
      final portNum = int.tryParse(parts[1].replaceAll(RegExp(r'[^0-9]'), ''));
      if (portNum != null && portNum > 0 && portNum <= 65535) {
        validPort = portNum.toString();
      }
    }

    return ParsedHostPort(ip: ipPart, port: validPort);
  }
}
