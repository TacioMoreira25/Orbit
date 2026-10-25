import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'http_upload_service.dart';
import '../viewmodels/home_viewmodel.dart';

class NetworkScanResult {
  final String? discoveredIp;
  final String scannedSubnet;

  const NetworkScanResult({
    required this.discoveredIp,
    required this.scannedSubnet,
  });
}

class NetworkScannerService {
  final HttpUploadService _httpService;

  NetworkScannerService(this._httpService);

  Future<String?> detectSubnetAndDeviceIps(Set<String> deviceIps) async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && addr.address.contains('.')) {
            deviceIps.add(addr.address);
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              return '${parts[0]}.${parts[1]}.${parts[2]}';
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<bool> probeOrbitHost(String ip, int port) async {
    Socket? socket;
    try {
      socket = await Socket.connect(ip, port, timeout: const Duration(milliseconds: 350));
      socket.destroy();
    } catch (_) {
      return false;
    }

    try {
      return await _httpService.checkHealth('http://$ip:$port');
    } catch (_) {
      return false;
    }
  }

  Future<NetworkScanResult> scanSubnet({
    required int port,
    String? preferredInputIp,
    String? lastConnectedIp,
    bool Function()? isCancelled,
  }) async {
    final myDeviceIps = <String>{};
    final autoDetectedSubnet = await detectSubnetAndDeviceIps(myDeviceIps);

    String subnet = autoDetectedSubnet ?? '192.168.1';
    final currentInput = preferredInputIp?.trim() ?? '';

    if (currentInput.contains('.')) {
      final parts = currentInput.split('.');
      if (parts.length >= 3 && parts[0].isNotEmpty && parts[1].isNotEmpty && parts[2].isNotEmpty) {
        subnet = '${parts[0]}.${parts[1]}.${parts[2]}';
      }
    } else if (lastConnectedIp != null && lastConnectedIp.contains('.')) {
      final parts = lastConnectedIp.split('.');
      if (parts.length >= 3) {
        subnet = '${parts[0]}.${parts[1]}.${parts[2]}';
      }
    }

    final candidateIps = <String>[];
    if (lastConnectedIp != null && !myDeviceIps.contains(lastConnectedIp)) {
      candidateIps.add(lastConnectedIp);
    }

    for (int i = 2; i <= 254; i++) {
      final ip = '$subnet.$i';
      if (!candidateIps.contains(ip) && !myDeviceIps.contains(ip)) {
        candidateIps.add(ip);
      }
    }

    String? found;
    const batchSize = 25;
    for (int i = 0; i < candidateIps.length; i += batchSize) {
      if ((isCancelled != null && isCancelled()) || found != null) break;
      final end = (i + batchSize < candidateIps.length) ? i + batchSize : candidateIps.length;
      final batch = candidateIps.sublist(i, end);

      final results = await Future.wait(
        batch.map((ip) async {
          final isOrbit = await probeOrbitHost(ip, port);
          return isOrbit ? ip : null;
        }),
      );

      found = results.firstWhere((ip) => ip != null, orElse: () => null);
      if (found != null) break;
    }

    return NetworkScanResult(discoveredIp: found, scannedSubnet: subnet);
  }
}

final networkScannerServiceProvider = Provider<NetworkScannerService>((ref) {
  return NetworkScannerService(ref.watch(httpUploadServiceProvider));
});
