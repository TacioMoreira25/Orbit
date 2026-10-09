enum ClipboardType {
  text,
  url,
  code,
  json,
  markdown,
}

class ClipboardPayload {
  final String text;
  final ClipboardType type;
  final String? language;
  final DateTime timestamp;

  const ClipboardPayload({
    required this.text,
    this.type = ClipboardType.text,
    this.language,
    required this.timestamp,
  });
}
