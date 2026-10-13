import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transfer_state.dart';
import '../viewmodels/transfer_viewmodel.dart';
import '../widgets/transfer_progress_bar.dart';

class TransferScreen extends ConsumerWidget {
  const TransferScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transferState = ref.watch(transferViewModelProvider);
    final transfers = transferState.transfers;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      appBar: AppBar(
        title: const Text('Transferências', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: transfers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_upload_outlined, size: 64, color: Colors.grey.withOpacity(0.4)),
                  const SizedBox(height: 16),
                  const Text(
                    'Nenhuma transferência ativa',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: transfers.length,
              itemBuilder: (context, index) {
                final item = transfers[index];
                return TransferProgressBar(
                  item: item,
                  onRetry: item.status == TransferStatus.failed
                      ? () => ref.read(transferViewModelProvider.notifier).retryTransfer(item.id)
                      : null,
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: transferState.isSelectingFile
            ? null
            : () => ref.read(transferViewModelProvider.notifier).pickAndUploadFiles(),
        backgroundColor: Colors.cyan,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('Enviar Arquivos', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
