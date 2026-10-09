import 'package:flutter/material.dart';
import '../models/device.dart';

class DeviceCard extends StatelessWidget {
  final Device? device;
  final VoidCallback onConnectPressed;
  final VoidCallback onDisconnectPressed;

  const DeviceCard({
    super.key,
    required this.device,
    required this.onConnectPressed,
    required this.onDisconnectPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isConnected = device != null;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isConnected ? Colors.cyan.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
        ),
      ),
      color: isConnected ? const Color(0xFF13222B) : const Color(0xFF1B1D22),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isConnected ? Colors.cyan.withOpacity(0.15) : Colors.grey.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.laptop_chromebook,
                    color: isConnected ? Colors.cyanAccent : Colors.grey,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isConnected ? device!.name : 'Nenhum PC conectado',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isConnected ? '${device!.host}:${device!.port}' : 'Conecte-se para transferir arquivos',
                        style: TextStyle(
                          fontSize: 13,
                          color: isConnected ? Colors.cyanAccent.withOpacity(0.8) : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isConnected ? Colors.greenAccent : Colors.redAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: isConnected
                  ? OutlinedButton.icon(
                      onPressed: onDisconnectPressed,
                      icon: const Icon(Icons.link_off, color: Colors.redAccent, size: 18),
                      label: const Text('Desconectar', style: TextStyle(color: Colors.redAccent)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: onConnectPressed,
                      icon: const Icon(Icons.qr_code_scanner, size: 18),
                      label: const Text('Parear via QR Code'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyan,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
