import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/device.dart';
import '../services/http_upload_service.dart';
import 'home_viewmodel.dart';

class PairingState {
  final bool isLoading;
  final String? errorMessage;
  final bool isSuccess;

  const PairingState({
    this.isLoading = false,
    this.errorMessage,
    this.isSuccess = false,
  });

  PairingState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? isSuccess,
  }) {
    return PairingState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

class PairingViewModel extends StateNotifier<PairingState> {
  final HttpUploadService _httpService;
  final Ref _ref;

  PairingViewModel({
    required HttpUploadService httpService,
    required Ref ref,
  })  : _httpService = httpService,
        _ref = ref,
        super(const PairingState());

  Future<bool> _authenticateAndConnect({
    required String ip,
    required int port,
    required String pin,
    String? fallbackServerName,
    String? fallbackToken,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final response = await _httpService.pairDevice(
        serverBaseUrl: 'http://$ip:$port',
        pin: pin,
        deviceName: 'Android Device',
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final serverName = response.data['serverDeviceName'] as String? ?? fallbackServerName ?? 'Linux PC';
        final authorizedToken = response.data['token'] as String? ?? fallbackToken;

        final pairedDevice = Device(
          id: 'linux-server',
          name: serverName,
          host: ip,
          port: port,
          token: authorizedToken,
          isPaired: true,
        );

        _ref.read(homeViewModelProvider.notifier).setConnectedDevice(pairedDevice);
        state = state.copyWith(isLoading: false, isSuccess: true);
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: response.data is Map
              ? (response.data['error'] ?? response.data['message'] ?? 'PIN incorreto ou expirado.')
              : 'PIN incorreto ou expirado.',
        );
        return false;
      }
    } catch (e) {
      final msg = HttpUploadService.extractErrorMessage(e);
      state = state.copyWith(
        isLoading: false,
        errorMessage: msg,
      );
      return false;
    }
  }

  Future<bool> pairWithQrCodePayload(String qrJson) async {
    try {
      final data = jsonDecode(qrJson);
      final ip = data['ip'] as String;
      final port = (data['port'] as num).toInt();
      final pin = data['pin'] as String;
      final serverName = data['deviceName'] as String?;
      final token = data['token'] as String?;

      return await _authenticateAndConnect(
        ip: ip,
        port: port,
        pin: pin,
        fallbackServerName: serverName,
        fallbackToken: token,
      );
    } catch (e) {
      final msg = HttpUploadService.extractErrorMessage(e);
      state = state.copyWith(
        isLoading: false,
        errorMessage: msg,
      );
      return false;
    }
  }

  Future<bool> pairWithManualInput(String ip, int port, String pin) async {
    return await _authenticateAndConnect(
      ip: ip,
      port: port,
      pin: pin,
    );
  }
}

final pairingViewModelProvider = StateNotifierProvider<PairingViewModel, PairingState>((ref) {
  return PairingViewModel(
    httpService: ref.watch(httpUploadServiceProvider),
    ref: ref,
  );
});
