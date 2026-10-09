import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/device.dart';
import '../services/clipboard_service.dart';
import '../services/http_upload_service.dart';
import '../services/web_socket_service.dart';

class HomeState {
  final Device? connectedDevice;
  final bool isConnecting;
  final String? lastSyncedText;
  final String? statusMessage;

  const HomeState({
    this.connectedDevice,
    this.isConnecting = false,
    this.lastSyncedText,
    this.statusMessage,
  });

  HomeState copyWith({
    Device? connectedDevice,
    bool? isConnecting,
    String? lastSyncedText,
    String? statusMessage,
    bool clearDevice = false,
  }) {
    return HomeState(
      connectedDevice: clearDevice ? null : (connectedDevice ?? this.connectedDevice),
      isConnecting: isConnecting ?? this.isConnecting,
      lastSyncedText: lastSyncedText ?? this.lastSyncedText,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}

class HomeViewModel extends StateNotifier<HomeState> {
  final HttpUploadService _httpService;
  final WebSocketService _wsService;
  final MobileClipboardService _clipboardService;
  final String deviceId = 'android-${DateTime.now().millisecondsSinceEpoch % 10000}';

  HomeViewModel({
    required HttpUploadService httpService,
    required WebSocketService wsService,
    required MobileClipboardService clipboardService,
  })  : _httpService = httpService,
        _wsService = wsService,
        _clipboardService = clipboardService,
        super(const HomeState());

  void setConnectedDevice(Device device) {
    state = state.copyWith(connectedDevice: device, statusMessage: 'Conectado a ${device.name}');
    _wsService.connect(device.wsUrl, deviceId);
  }

  void disconnect() {
    _wsService.disconnect();
    state = state.copyWith(clearDevice: true, statusMessage: 'Desconectado');
  }

  Future<bool> syncCurrentClipboard() async {
    final device = state.connectedDevice;
    if (device == null) {
      state = state.copyWith(statusMessage: 'Nenhum dispositivo conectado!');
      return false;
    }

    try {
      final text = await _clipboardService.getSystemClipboardText();
      if (text.isEmpty) {
        state = state.copyWith(statusMessage: 'Área de transferência vazia.');
        return false;
      }

      await _httpService.sendClipboard(
        serverBaseUrl: device.baseUrl,
        content: text,
        deviceId: deviceId,
      );

      state = state.copyWith(
        lastSyncedText: text,
        statusMessage: 'Texto sincronizado com o Linux!',
      );
      return true;
    } catch (e) {
      state = state.copyWith(statusMessage: 'Falha ao sincronizar clipboard: $e');
      return false;
    }
  }
}

final httpUploadServiceProvider = Provider((ref) => HttpUploadService());
final webSocketServiceProvider = Provider((ref) => WebSocketService());
final mobileClipboardServiceProvider = Provider((ref) => MobileClipboardService());

final homeViewModelProvider = StateNotifierProvider<HomeViewModel, HomeState>((ref) {
  return HomeViewModel(
    httpService: ref.watch(httpUploadServiceProvider),
    wsService: ref.watch(webSocketServiceProvider),
    clipboardService: ref.watch(mobileClipboardServiceProvider),
  );
});
