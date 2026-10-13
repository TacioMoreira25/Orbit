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

  Future<bool> pairWithQrCodePayload(String qrJson) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final data = jsonDecode(qrJson);
      final ip = data['ip'] as String;
      final port = (data['port'] as num).toInt();
      final pin = data['pin'] as String;
      final serverName = data['deviceName'] as String? ?? 'Linux PC';
      final token = data['token'] as String?;

      final response = await _httpService.pairDevice(
        serverBaseUrl: 'http://$ip:$port',
        pin: pin,
        deviceName: 'Android Device',
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final authorizedToken = response.data['token'] ?? token;
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
              ? (response.data['error'] ?? response.data['message'] ?? 'Falha ao parear dispositivo.')
              : 'Falha ao parear dispositivo.',
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

  Future<bool> pairWithManualInput(String ip, int port, String pin) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final response = await _httpService.pairDevice(
        serverBaseUrl: 'http://$ip:$port',
        pin: pin,
        deviceName: 'Android Device',
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final token = response.data['token'];
        final serverName = response.data['serverDeviceName'] ?? 'Linux PC';

        final pairedDevice = Device(
          id: 'linux-server',
          name: serverName,
          host: ip,
          port: port,
          token: token,
          isPaired: true,
        );

        _ref.read(homeViewModelProvider.notifier).setConnectedDevice(pairedDevice);
        state = state.copyWith(isLoading: false, isSuccess: true);
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: response.data is Map
              ? (response.data['error'] ?? response.data['message'] ?? 'PIN inválido ou expirado.')
              : 'PIN inválido ou expirado.',
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
}

final pairingViewModelProvider = StateNotifierProvider<PairingViewModel, PairingState>((ref) {
  return PairingViewModel(
    httpService: ref.watch(httpUploadServiceProvider),
    ref: ref,
  );
});
