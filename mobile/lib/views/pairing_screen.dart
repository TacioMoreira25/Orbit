import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../viewmodels/pairing_viewmodel.dart';

class PairingScreen extends ConsumerStatefulWidget {
  final int initialTab;

  const PairingScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '3000');
  final _pinController = TextEditingController();
  bool _isProcessingCode = false;
  bool _hasCameraPermission = false;
  bool _isCheckingPermission = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _checkCameraPermission();
  }

  Future<void> _checkCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      if (mounted) setState(() { _hasCameraPermission = true; _isCheckingPermission = false; });
    } else {
      final requested = await Permission.camera.request();
      if (mounted) {
        setState(() {
          _hasCameraPermission = requested.isGranted;
          _isCheckingPermission = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ipController.dispose();
    _portController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pairingState = ref.watch(pairingViewModelProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Fechar',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Parear com Linux', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.cyan,
          indicatorWeight: 3,
          labelColor: Colors.cyanAccent,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.qr_code_scanner), text: 'QR Code'),
            Tab(icon: Icon(Icons.keyboard), text: 'IP & PIN Manual'),
          ],
        ),
      ),
      body: pairingState.isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.cyan),
                  SizedBox(height: 16),
                  Text('Conectando ao computador...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                // Aba 1: Scanner de QR Code
                _buildQrScanner(),

                // Aba 2: Manual
                _buildManualForm(),
              ],
            ),
    );
  }

  Widget _buildQrScanner() {
    if (_isCheckingPermission) {
      return const Center(child: CircularProgressIndicator(color: Colors.cyan));
    }

    if (!_hasCameraPermission) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.cyan.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.videocam_off_outlined, size: 48, color: Colors.cyan),
              ),
              const SizedBox(height: 20),
              const Text(
                'Permissão de Câmera Necessária',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                'O Orbit precisa de acesso à câmera para ler o QR Code de pareamento do terminal.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _checkCameraPermission,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Conceder Permissão'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => _tabController.animateTo(1),
                icon: const Icon(Icons.keyboard_outlined, size: 18, color: Colors.grey),
                label: const Text('Inserir IP e PIN manualmente', style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Aponte a câmera para o QR Code gerado no terminal do servidor Linux.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.cyan.withValues(alpha: 0.3), width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: MobileScanner(
                onDetect: (capture) async {
                  if (_isProcessingCode) return;
                  final barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                    setState(() => _isProcessingCode = true);
                    final rawJson = barcodes.first.rawValue!;
                    final success = await ref
                        .read(pairingViewModelProvider.notifier)
                        .pairWithQrCodePayload(rawJson);

                    if (!mounted) return;
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Conectado ao Linux com sucesso via QR Code!'),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      Navigator.of(context).pop();
                    } else {
                      final error = ref.read(pairingViewModelProvider).errorMessage ?? 'Código QR inválido ou expirado.';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(error),
                          backgroundColor: Colors.redAccent,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      setState(() => _isProcessingCode = false);
                    }
                  }
                },
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: OutlinedButton.icon(
            onPressed: () => _tabController.animateTo(1),
            icon: const Icon(Icons.edit_note, size: 18, color: Colors.cyan),
            label: const Text('Prefiro digitar IP e PIN manualmente', style: TextStyle(color: Colors.cyan)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.cyan.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManualForm() {
    final pairingState = ref.watch(pairingViewModelProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _ipController,
            decoration: InputDecoration(
              labelText: 'Endereço IP do Linux (ex: 10.0.2.2 ou 192.168.1.10)',
              prefixIcon: const Icon(Icons.wifi, color: Colors.cyan),
              suffixIcon: _ipController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(() => _ipController.clear()),
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF1B1D22),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            keyboardType: TextInputType.url,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.phone_android, size: 14, color: Colors.cyan),
                label: const Text('Emulador (10.0.2.2)', style: TextStyle(fontSize: 12)),
                backgroundColor: const Color(0xFF1E2128),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                onPressed: () => setState(() => _ipController.text = '10.0.2.2'),
              ),
              ActionChip(
                avatar: const Icon(Icons.computer, size: 14, color: Colors.cyan),
                label: const Text('Localhost (127.0.0.1)', style: TextStyle(fontSize: 12)),
                backgroundColor: const Color(0xFF1E2128),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                onPressed: () => setState(() => _ipController.text = '127.0.0.1'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _portController,
            decoration: InputDecoration(
              labelText: 'Porta (Padrão: 3000)',
              prefixIcon: const Icon(Icons.numbers, color: Colors.cyan),
              filled: true,
              fillColor: const Color(0xFF1B1D22),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pinController,
            decoration: InputDecoration(
              labelText: 'PIN de 4 dígitos (exibido no terminal)',
              prefixIcon: const Icon(Icons.lock_outline, color: Colors.cyan),
              filled: true,
              fillColor: const Color(0xFF1B1D22),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            maxLength: 4,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),
          if (pairingState.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      pairingState.errorMessage!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          ElevatedButton(
            onPressed: () async {
              // Fecha o teclado para dar visibilidade imediata ao formulário e eventuais mensagens
              FocusScope.of(context).unfocus();

              final ip = _ipController.text.trim();
              final portText = _portController.text.trim();
              final pin = _pinController.text.trim();

              if (ip.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Informe o endereço IP do servidor Linux.'),
                    backgroundColor: Colors.redAccent,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }

              final port = int.tryParse(portText);
              if (port == null || port <= 0 || port > 65535) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Porta inválida. Digite um valor entre 1 e 65535.'),
                    backgroundColor: Colors.redAccent,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }

              if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('O PIN deve conter exatamente 4 números.'),
                    backgroundColor: Colors.redAccent,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }

              final success = await ref
                  .read(pairingViewModelProvider.notifier)
                  .pairWithManualInput(ip, port, pin);

              if (!mounted) return;
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Conectado ao Linux com sucesso!'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                Navigator.of(context).pop();
              } else {
                final error = ref.read(pairingViewModelProvider).errorMessage ?? 'PIN de pareamento incorreto ou inexistente.';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(error),
                    backgroundColor: Colors.redAccent,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyan,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Conectar e Parear', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
