enum TransferStatus {
  idle,
  hashing,
  uploading,
  verifying,
  completed,
  failed,
}

class TransferItem {
  final String id;
  final String filename;
  final int totalBytes;
  final int bytesTransferred;
  final double percentage;
  final TransferStatus status;
  final String? errorMessage;
  final DateTime startedAt;
  final DateTime? completedAt;

  const TransferItem({
    required this.id,
    required this.filename,
    required this.totalBytes,
    this.bytesTransferred = 0,
    this.percentage = 0.0,
    this.status = TransferStatus.idle,
    this.errorMessage,
    required this.startedAt,
    this.completedAt,
  });

  TransferItem copyWith({
    String? id,
    String? filename,
    int? totalBytes,
    int? bytesTransferred,
    double? percentage,
    TransferStatus? status,
    String? errorMessage,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return TransferItem(
      id: id ?? this.id,
      filename: filename ?? this.filename,
      totalBytes: totalBytes ?? this.totalBytes,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      percentage: percentage ?? this.percentage,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
