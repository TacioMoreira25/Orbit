import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../viewmodels/pairing_viewmodel.dart';

class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key});

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '3000');
  final _pinController = TextEditingController();
  bool _isProcessingCode = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
        title: const Text('Parear com Linux', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.cyan,
          tabs: const [
            Tab(icon: Icon(Icons.qr_code_scanner), text: 'Escanear QR Code'),
            Tab(icon: Icon(Icons.keyboard), text: 'Inserir Manualmente'),
          ],
        ),
      ),
      body: pairingState.isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.cyan))
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
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
                    Navigator.of(context).pop();
                  } else {
                    setState(() => _isProcessingCode = false);
                  }
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildManualForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _ipController,
            decoration: InputDecoration(
              labelText: 'Endereço IP do Linux (ex: 192.168.1.10)',
              prefixIcon: const Icon(Icons.wifi, color: Colors.cyan),
              filled: true,
              fillColor: const Color(0xFF1B1D22),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            keyboardType: TextInputType.url,
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
          ElevatedButton(
            onPressed: () async {
              final ip = _ipController.text.trim();
              final port = int.tryParse(_portController.text.trim()) ?? 3000;
              final pin = _pinController.text.trim();

              if (ip.isEmpty || pin.length != 4) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Preencha o IP e o PIN de 4 dígitos')),
                );
                return;
              }

              final success = await ref
                  .read(pairingViewModelProvider.notifier)
                  .pairWithManualInput(ip, port, pin);

              if (!mounted) return;
              if (success) {
                Navigator.of(context).pop();
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
        ],
      ),
    );
  }
}
