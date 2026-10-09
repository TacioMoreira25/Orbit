class FilePayload {
  final String id;
  final String name;
  final String path;
  final int sizeBytes;
  final String? sha256;
  final String? mimeType;

  const FilePayload({
    required this.id,
    required this.name,
    required this.path,
    required this.sizeBytes,
    this.sha256,
    this.mimeType,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    if (sizeBytes < 1024 * 1024 * 1024) return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
