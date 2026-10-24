import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/http_upload_service.dart';
import '../utils/ip_input_formatter.dart';
import '../viewmodels/home_viewmodel.dart';
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
  final _pinFocusNode = FocusNode();
  bool _isProcessingCode = false;
  bool _hasCameraPermission = false;
  bool _isCheckingPermission = true;

  String? _lastConnectedIp;
  String? _lastConnectedPort;
  bool _isScanningNetwork = false;
  String? _discoveredIp;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _checkCameraPermission();
    _loadLastConnection();
  }

  Future<void> _loadLastConnection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ip = prefs.getString('orbit_last_connected_ip');
      final port = prefs.getString('orbit_last_connected_port');
      if (ip != null && ip.isNotEmpty && mounted) {
        setState(() {
          _lastConnectedIp = ip;
          _lastConnectedPort = port ?? '3000';
        });
      }
    } catch (_) {}
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

  Future<void> _saveLastConnection(String ip, String port) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('orbit_last_connected_ip', ip);
      await prefs.setString('orbit_last_connected_port', port);
    } catch (_) {}
  }

  Future<void> _pasteIpFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final raw = data?.text?.trim() ?? '';
    if (raw.isEmpty) return;

    // Suporta formatos como: 192.168.1.155, 192.168.1.155:3000 ou http://192.168.1.155:3000
    final cleaned = raw.replaceAll(RegExp(r'^https?://'), '');
    final parts = cleaned.split(':');
    final ipPart = parts[0].replaceAll(RegExp(r'[^0-9.]'), '');

    if (ipPart.isNotEmpty && mounted) {
      setState(() {
        _ipController.text = ipPart;
        if (parts.length > 1) {
          final portNum = int.tryParse(parts[1].replaceAll(RegExp(r'[^0-9]'), ''));
          if (portNum != null && portNum > 0 && portNum <= 65535) {
            _portController.text = portNum.toString();
          }
        }
      });
      _pinFocusNode.requestFocus();
    }
  }

  Future<void> _scanLocalNetwork() async {
    if (_isScanningNetwork) return;
    setState(() {
      _isScanningNetwork = true;
      _discoveredIp = null;
    });

    try {
      // Determina sub-rede provável baseando-se no último IP ou no IP digitado
      String subnet = '192.168.1';
      final currentInput = _ipController.text.trim();
      if (currentInput.contains('.')) {
        final parts = currentInput.split('.');
        if (parts.length >= 3) {
          subnet = '${parts[0]}.${parts[1]}.${parts[2]}';
        }
      } else if (_lastConnectedIp != null && _lastConnectedIp!.contains('.')) {
        final parts = _lastConnectedIp!.split('.');
        if (parts.length >= 3) {
          subnet = '${parts[0]}.${parts[1]}.${parts[2]}';
        }
      }

      final port = _portController.text.trim().isNotEmpty ? _portController.text.trim() : '3000';
      final httpService = ref.read(httpUploadServiceProvider);

      // Tenta primeiro o último IP conectado, depois os hosts mais comuns da sub-rede
      final candidateIps = <String>[];
      if (_lastConnectedIp != null) candidateIps.add(_lastConnectedIp!);
      for (int i = 2; i <= 254; i++) {
        final ip = '$subnet.$i';
        if (!candidateIps.contains(ip)) candidateIps.add(ip);
      }

      // Escaneia em lotes de 15 requisições paralelas para resposta ágil
      String? found;
      for (int i = 0; i < candidateIps.length; i += 15) {
        if (!mounted || found != null) break;
        final batch = candidateIps.sublist(i, (i + 15 < candidateIps.length) ? i + 15 : candidateIps.length);
        final results = await Future.wait(
          batch.map((ip) async {
            final ok = await httpService.checkHealth('http://$ip:$port');
            return ok ? ip : null;
          }),
        );
        found = results.firstWhere((ip) => ip != null, orElse: () => null);
        if (found != null) break;
      }

      if (mounted) {
        setState(() {
          _isScanningNetwork = false;
          _discoveredIp = found;
        });

        if (found != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Servidor Orbit detectado em $found!'),
              backgroundColor: Colors.teal,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nenhum servidor Orbit respondeu na sub-rede atual. Insira o IP manualmente.'),
              backgroundColor: Colors.orangeAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isScanningNetwork = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ipController.dispose();
    _portController.dispose();
    _pinController.dispose();
    _pinFocusNode.dispose();
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
                      try {
                        final data = jsonDecode(rawJson);
                        final qrIp = data['ip']?.toString();
                        final qrPort = data['port']?.toString() ?? '3000';
                        if (qrIp != null) _saveLastConnection(qrIp, qrPort);
                      } catch (_) {}
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
              labelText: 'Endereço IP do Linux',
              hintText: '192.168.1.10',
              prefixIcon: const Icon(Icons.wifi, color: Colors.cyan),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_ipController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      tooltip: 'Limpar IP',
                      onPressed: () => setState(() => _ipController.clear()),
                    ),
                  IconButton(
                    icon: const Icon(Icons.content_paste_rounded, size: 18, color: Colors.cyan),
                    tooltip: 'Colar IP copiado',
                    onPressed: _pasteIpFromClipboard,
                  ),
                  const SizedBox(width: 4),
                ],
              ),
              filled: true,
              fillColor: const Color(0xFF1B1D22),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [IpAddressInputFormatter()],
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
          ),
          if (_discoveredIp != null) ...[
            const SizedBox(height: 10),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() => _ipController.text = _discoveredIp!);
                _pinFocusNode.requestFocus();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.tealAccent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'PC Orbit detectado: $_discoveredIp (Toque para usar)',
                        style: const TextStyle(color: Colors.tealAccent, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (_lastConnectedIp != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(
                avatar: const Icon(Icons.history_rounded, size: 16, color: Colors.cyanAccent),
                label: Text('Último: $_lastConnectedIp', style: const TextStyle(fontSize: 12, color: Colors.cyanAccent)),
                backgroundColor: const Color(0xFF1B1D22),
                side: BorderSide(color: Colors.cyan.withValues(alpha: 0.25)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                onPressed: () {
                  setState(() {
                    _ipController.text = _lastConnectedIp!;
                    if (_lastConnectedPort != null) _portController.text = _lastConnectedPort!;
                  });
                  _pinFocusNode.requestFocus();
                },
              ),
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _isScanningNetwork ? null : _scanLocalNetwork,
              icon: _isScanningNetwork
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyan),
                    )
                  : const Icon(Icons.radar_rounded, size: 18, color: Colors.cyan),
              label: Text(
                _isScanningNetwork ? 'Buscando servidor Orbit na rede...' : 'Buscar PC na rede local',
                style: const TextStyle(color: Colors.cyan, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _portController,
            decoration: InputDecoration(
              labelText: 'Porta',
              hintText: 'Padrão: 3000',
              prefixIcon: const Icon(Icons.numbers, color: Colors.cyan),
              filled: true,
              fillColor: const Color(0xFF1B1D22),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pinController,
            focusNode: _pinFocusNode,
            decoration: InputDecoration(
              labelText: 'PIN de 4 dígitos',
              hintText: 'Exibido no terminal do PC',
              prefixIcon: const Icon(Icons.lock_outline, color: Colors.cyan),
              filled: true,
              fillColor: const Color(0xFF1B1D22),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            maxLength: 4,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                _saveLastConnection(ip, port.toString());
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
