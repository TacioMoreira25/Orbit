import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

class QrScannerView extends StatelessWidget {
  final bool isCheckingPermission;
  final bool hasCameraPermission;
  final bool isPermanentlyDenied;
  final MobileScannerController scannerController;
  final VoidCallback onRequestPermission;
  final VoidCallback onSwitchToManualTab;
  final void Function(BarcodeCapture capture) onDetect;

  const QrScannerView({
    super.key,
    required this.isCheckingPermission,
    required this.hasCameraPermission,
    required this.isPermanentlyDenied,
    required this.scannerController,
    required this.onRequestPermission,
    required this.onSwitchToManualTab,
    required this.onDetect,
  });

  @override
  Widget build(BuildContext context) {
    if (isCheckingPermission) {
      return const Center(child: CircularProgressIndicator(color: Colors.cyan));
    }

    if (!hasCameraPermission) {
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
              Text(
                isPermanentlyDenied
                    ? 'A permissão da câmera foi negada. Abra as configurações do aplicativo para habilitar a câmera e ler o QR Code.'
                    : 'O Orbit precisa de acesso à câmera para ler o QR Code de pareamento do terminal.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: isPermanentlyDenied ? () => openAppSettings() : onRequestPermission,
                icon: Icon(isPermanentlyDenied ? Icons.settings : Icons.camera_alt),
                label: Text(isPermanentlyDenied ? 'Abrir Configurações do App' : 'Conceder Permissão'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: onSwitchToManualTab,
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
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: scannerController,
                    errorBuilder: (context, error, child) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.videocam_off_outlined, color: Colors.orangeAccent, size: 48),
                              const SizedBox(height: 16),
                              const Text(
                                'Não foi possível inicializar a câmera',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                error.errorDetails?.message ?? error.errorCode.name,
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => scannerController.start(),
                                icon: const Icon(Icons.refresh),
                                label: const Text('Tentar Novamente'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.cyan,
                                  foregroundColor: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    onDetect: onDetect,
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.flash_on, color: Colors.cyanAccent),
                        tooltip: 'Alternar Lanterna',
                        onPressed: () => scannerController.toggleTorch(),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.flip_camera_android, color: Colors.white70),
                        tooltip: 'Alternar Câmera',
                        onPressed: () => scannerController.switchCamera(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: OutlinedButton.icon(
            onPressed: onSwitchToManualTab,
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
}
