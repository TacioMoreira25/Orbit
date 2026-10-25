import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transfer_state.dart';
import '../services/share_intent_service.dart';
import '../viewmodels/home_viewmodel.dart';
import '../viewmodels/transfer_viewmodel.dart';
import '../widgets/device_card.dart';
import '../widgets/transfer_progress_bar.dart';
import 'pairing_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Inicializa listener do Share Intent para arquivos compartilhados pelo Android
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(shareIntentServiceProvider).initialize(
        onFilesReceived: (paths) {
          _handleSharedFiles(paths);
        },
      );
      ref.read(transferViewModelProvider.notifier).checkPendingFilesFromPc();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reconecta e puxa arquivos pendentes assim que o usuário volta para o app
      final homeState = ref.read(homeViewModelProvider);
      if (homeState.connectedDevice != null) {
        ref.read(transferViewModelProvider.notifier).checkPendingFilesFromPc();
      }
    }
  }

  void _openPairing(BuildContext context, [int tab = 0]) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PairingScreen(initialTab: tab)),
    );
  }

  void _handleSharedFiles(List<String> paths) {
    if (paths.isEmpty) return;

    final homeState = ref.read(homeViewModelProvider);
    if (homeState.connectedDevice == null) {
      if (!mounted) return;
      _showConnectPrompt(
        context,
        title: 'Arquivos Recebidos',
        message: 'Você compartilhou ${paths.length} arquivo(s), mas precisa conectar seu PC primeiro para transferir.',
      );
      return;
    }

    // Inicia transferências imediatamente na própria tela inicial
    ref.read(transferViewModelProvider.notifier).uploadFromSharedFiles(paths);
  }

  void _showConnectPrompt(BuildContext context, {String? title, String? message}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16181F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/images/orbit_logo.png',
                width: 68,
                height: 68,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title ?? 'Conexão Necessária',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              message ?? 'Para enviar arquivos ou sincronizar o clipboard, conecte-se ao Orbit rodando no seu Linux.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openPairing(context, 1);
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.cyan.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Inserir IP/PIN', style: TextStyle(color: Colors.cyanAccent)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openPairing(context, 0);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyan,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Ler QR Code', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmExitApp(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B1D22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.redAccent, size: 24),
            SizedBox(width: 10),
            Text('Fechar o Orbit', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Deseja realmente sair e encerrar o aplicativo?',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              SystemNavigator.pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Sair do App', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeViewModelProvider);
    final homeNotifier = ref.read(homeViewModelProvider.notifier);
    final transferState = ref.watch(transferViewModelProvider);
    final transferNotifier = ref.read(transferViewModelProvider.notifier);
    final transfers = transferState.transfers;
    final isConnected = homeState.connectedDevice != null && homeState.connectedDevice!.isPaired;

    ref.listen<HomeState>(homeViewModelProvider, (prev, next) {
      if (next.statusMessage != null &&
          next.statusMessage != prev?.statusMessage &&
          next.statusMessage!.contains('recebido do Linux')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.statusMessage!),
            backgroundColor: Colors.teal,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      if (prev?.connectedDevice == null && next.connectedDevice != null) {
        transferNotifier.checkPendingFilesFromPc();
      }
    });

    ref.listen<TransferListState>(transferViewModelProvider, (prev, next) {
      final prevCount = prev?.transfers.length ?? 0;
      if (next.transfers.length > prevCount) {
        final newest = next.transfers.first;
        if (newest.id.startsWith('download-')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Recebendo arquivo do PC: ${newest.filename}'),
              backgroundColor: Colors.cyan.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/orbit_logo.png',
                width: 32,
                height: 32,
                fit: BoxFit.contain,
              ),
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
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            tooltip: 'Sair do Orbit',
            onPressed: () => _confirmExitApp(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card de Status do Dispositivo Conectado
            DeviceCard(
              device: homeState.connectedDevice,
              onConnectPressed: () => _openPairing(context, 0),
              onManualConnectPressed: () => _openPairing(context, 1),
              onDisconnectPressed: () => homeNotifier.disconnect(),
            ),

            const SizedBox(height: 28),

            // Ações Rápidas
            const Row(
              children: [
                Icon(Icons.flash_on_rounded, color: Colors.cyanAccent, size: 20),
                SizedBox(width: 8),
                Text(
                  'Ações Rápidas',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Botão Enviar Arquivos
            _buildActionCard(
              context: context,
              icon: Icons.upload_file_rounded,
              iconColor: Colors.cyanAccent,
              title: 'Enviar Arquivos',
              subtitle: 'Fotos, vídeos e documentos direto para o Linux',
              enabled: isConnected,
              onTap: () {
                if (!isConnected) {
                  _showConnectPrompt(context);
                  return;
                }
                transferNotifier.pickAndUploadFiles();
              },
            ),

            const SizedBox(height: 14),

            // Botão Sincronizar Clipboard
            _buildActionCard(
              context: context,
              icon: Icons.content_paste_go_rounded,
              iconColor: Colors.tealAccent,
              title: 'Sincronizar Clipboard',
              subtitle: 'Envia o texto copiado no celular para o PC agora',
              enabled: isConnected,
              onTap: () async {
                if (!isConnected) {
                  _showConnectPrompt(context);
                  return;
                }
                final result = await homeNotifier.syncCurrentClipboard();
                if (!context.mounted) return;
                if (result.success) {
                  final typeLabel = result.contentType != null && result.contentType != 'text'
                      ? ' [${result.contentType!.toUpperCase()}${result.detectedLanguage != null ? " - ${result.detectedLanguage}" : ""}]'
                      : '';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Conteúdo$typeLabel sincronizado com o Linux!'),
                      backgroundColor: Colors.teal,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result.errorMessage ?? 'Falha ao sincronizar clipboard.'),
                      backgroundColor: Colors.redAccent,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              },
            ),

            if (transfers.isNotEmpty) ...[
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.swap_vert_rounded, color: Colors.cyanAccent, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Transferências da Sessão',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => transferNotifier.clearFinishedTransfers(),
                    child: const Text('Limpar concluídas', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...transfers.map(
                (item) => TransferProgressBar(
                  item: item,
                  onRetry: (item.status == TransferStatus.failed || item.status == TransferStatus.cancelled)
                      ? () => transferNotifier.retryTransfer(item.id)
                      : null,
                  onCancel: (item.status == TransferStatus.uploading || item.status == TransferStatus.hashing)
                      ? () => transferNotifier.cancelTransfer(item.id)
                      : null,
                ),
              ),
            ],
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
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFF1B1D24) : const Color(0xFF15161B),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: enabled
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.04),
          ),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: enabled
                    ? iconColor.withValues(alpha: 0.14)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: enabled ? iconColor : Colors.grey.shade600,
                size: 26,
              ),
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
                      color: enabled ? Colors.white : Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: enabled ? Colors.grey : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              enabled ? Icons.chevron_right_rounded : Icons.lock_outline_rounded,
              color: enabled ? Colors.grey : Colors.grey.shade700,
              size: enabled ? 24 : 18,
            ),
          ],
        ),
      ),
    );
  }
}
