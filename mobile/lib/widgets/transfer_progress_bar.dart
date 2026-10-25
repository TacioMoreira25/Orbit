import 'package:flutter/material.dart';
import '../models/transfer_state.dart';

class TransferProgressBar extends StatelessWidget {
  final TransferItem item;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;

  const TransferProgressBar({
    super.key,
    required this.item,
    this.onRetry,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusText;

    switch (item.status) {
      case TransferStatus.idle:
        statusColor = Colors.grey;
        statusText = 'Aguardando';
        break;
      case TransferStatus.hashing:
        statusColor = Colors.orangeAccent;
        statusText = 'Calculando SHA-256 (Isolate)...';
        break;
      case TransferStatus.uploading:
        statusColor = Colors.cyanAccent;
        statusText = '${item.percentage.toStringAsFixed(0)}% (${_formatBytes(item.bytesTransferred)} / ${_formatBytes(item.totalBytes)})';
        break;
      case TransferStatus.verifying:
        statusColor = Colors.purpleAccent;
        statusText = 'Validando integridade...';
        break;
      case TransferStatus.completed:
        statusColor = Colors.greenAccent;
        statusText = 'Concluído (${_formatBytes(item.totalBytes)})';
        break;
      case TransferStatus.failed:
        statusColor = Colors.redAccent;
        statusText = 'Falha no envio';
        break;
      case TransferStatus.cancelled:
        statusColor = Colors.amberAccent;
        statusText = 'Cancelado';
        break;
    }

    final isUploadingOrHashing =
        item.status == TransferStatus.uploading || item.status == TransferStatus.hashing;
    final canRetry =
        item.status == TransferStatus.failed || item.status == TransferStatus.cancelled;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2128),
        borderRadius: BorderRadius.circular(12),
        border: item.status == TransferStatus.failed
            ? Border.all(color: Colors.redAccent.withValues(alpha: 0.3))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                item.status == TransferStatus.failed
                    ? Icons.error_outline
                    : item.status == TransferStatus.completed
                        ? Icons.check_circle_outline
                        : Icons.insert_drive_file_outlined,
                color: item.status == TransferStatus.failed
                    ? Colors.redAccent
                    : item.status == TransferStatus.completed
                        ? Colors.greenAccent
                        : Colors.cyan,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.filename,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                statusText,
                style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.bold),
              ),
              if (isUploadingOrHashing && onCancel != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                  tooltip: 'Cancelar transferência',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onCancel,
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: item.status == TransferStatus.completed
                  ? 1.0
                  : (item.status == TransferStatus.hashing ? null : (item.percentage / 100)),
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              minHeight: 6,
            ),
          ),
          if (item.status == TransferStatus.uploading && item.speedBytesPerSec > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.speed_rounded, size: 14, color: Colors.cyanAccent),
                    const SizedBox(width: 4),
                    Text(
                      '${_formatBytes(item.speedBytesPerSec.round())}/s',
                      style: const TextStyle(fontSize: 11, color: Colors.cyanAccent, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                if (item.etaSeconds != null && item.etaSeconds! > 0)
                  Text(
                    'Restam ~${_formatDuration(item.etaSeconds!)}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
              ],
            ),
          ] else if (item.status == TransferStatus.completed && item.speedBytesPerSec > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Velocidade média: ${_formatBytes(item.speedBytesPerSec.round())}/s • SHA-256 verificado',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
          if (canRetry) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.errorMessage ?? 'Ocorreu um erro durante a transferência.',
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                if (onRetry != null)
                  TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh, size: 16, color: Colors.cyan),
                    label: const Text('Tentar novamente', style: TextStyle(color: Colors.cyan, fontSize: 12)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins}m ${secs}s';
  }
}
