import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodels/home_viewmodel.dart';
import '../viewmodels/transfer_viewmodel.dart';
import '../widgets/device_card.dart';
import 'pairing_screen.dart';
import 'transfer_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeState = ref.watch(homeViewModelProvider);
    final homeNotifier = ref.read(homeViewModelProvider.notifier);
    final isConnected = homeState.connectedDevice != null;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.cyan,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.all_inclusive, color: Colors.black, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Orbit',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, letterSpacing: 1.1),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Transferências',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TransferScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card de Status do Dispositivo Conectado
            DeviceCard(
              device: homeState.connectedDevice,
              onConnectPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PairingScreen()),
                );
              },
              onDisconnectPressed: () => homeNotifier.disconnect(),
            ),

            const SizedBox(height: 28),

            // Ações Rápidas
            const Text(
              'Ações Rápidas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 16),

            // Botão Enviar Arquivos
            _buildActionCard(
              context: context,
              icon: Icons.upload_file,
              iconColor: Colors.cyanAccent,
              title: 'Enviar Arquivos',
              subtitle: 'Fotos, vídeos e documentos direto para o Linux',
              enabled: isConnected,
              onTap: () {
                ref.read(transferViewModelProvider.notifier).pickAndUploadFiles();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TransferScreen()),
                );
              },
            ),

            const SizedBox(height: 14),

            // Botão Sincronizar Clipboard
            _buildActionCard(
              context: context,
              icon: Icons.content_paste_go,
              iconColor: Colors.tealAccent,
              title: 'Sincronizar Clipboard',
              subtitle: 'Envia o texto copiado no celular para o PC agora',
              enabled: isConnected,
              onTap: () async {
                final success = await homeNotifier.syncCurrentClipboard();
                if (context.mounted && success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Texto enviado para a área de transferência do Linux!'),
                      backgroundColor: Colors.teal,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),

            const SizedBox(height: 32),

            // Card de Status do Sistema
            if (homeState.statusMessage != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1D22),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18, color: Colors.grey),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        homeState.statusMessage!,
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFF1B1D22) : const Color(0xFF16171B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: enabled ? Colors.white12 : Colors.white.withOpacity(0.04),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: enabled ? iconColor.withOpacity(0.12) : Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: enabled ? iconColor : Colors.grey.withOpacity(0.4), size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: enabled ? Colors.white : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: enabled ? Colors.grey : Colors.grey.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: enabled ? Colors.grey : Colors.grey.withOpacity(0.3),
            ),
          ],
        ),
      ),
    );
  }
}
