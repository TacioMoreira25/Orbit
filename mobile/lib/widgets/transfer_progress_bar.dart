import 'package:flutter/material.dart';
import '../models/transfer_state.dart';

class TransferProgressBar extends StatelessWidget {
  final TransferItem item;
  final VoidCallback? onRetry;

  const TransferProgressBar({
    super.key,
    required this.item,
    this.onRetry,
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
        statusText = 'Calculando SHA-256...';
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
        statusText = 'Concluído com sucesso!';
        break;
      case TransferStatus.failed:
        statusColor = Colors.redAccent;
        statusText = 'Falha no envio';
        break;
    }

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
                    : Icons.insert_drive_file_outlined,
                color: item.status == TransferStatus.failed ? Colors.redAccent : Colors.cyan,
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
          if (item.status == TransferStatus.failed) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.errorMessage ?? 'Ocorreu um erro durante a transferência.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.redAccent.withValues(alpha: 0.9),
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
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
