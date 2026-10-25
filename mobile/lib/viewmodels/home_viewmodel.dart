import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device.dart';
import '../services/clipboard_service.dart';
import '../services/http_upload_service.dart';
import '../services/web_socket_service.dart';

class ClipboardSyncResult {
  final bool success;
  final String? contentType;
  final String? detectedLanguage;
  final String? errorMessage;

  const ClipboardSyncResult({
    required this.success,
    this.contentType,
    this.detectedLanguage,
    this.errorMessage,
  });
}

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
  static const String _storageKey = 'orbit_saved_device';
  StreamSubscription? _wsSubscription;
  Timer? _healthCheckTimer;

  HomeViewModel({
    required HttpUploadService httpService,
    required WebSocketService wsService,
    required MobileClipboardService clipboardService,
  })  : _httpService = httpService,
        _wsService = wsService,
        _clipboardService = clipboardService,
        super(const HomeState()) {
    _listenIncomingEvents();
    loadSavedDevice();
    _startPeriodicHealthCheck();
  }

  @override
  void dispose() {
    _healthCheckTimer?.cancel();
    _wsSubscription?.cancel();
    super.dispose();
  }

  void _startPeriodicHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      final device = state.connectedDevice;
      if (device == null) return;

      final isOnline = await _httpService.checkHealth(device.baseUrl);
      if (isOnline && !device.isPaired) {
        state = state.copyWith(
          connectedDevice: device.copyWith(isPaired: true),
          statusMessage: 'Conectado a ${device.name}',
        );
        _wsService.connect(device.wsUrl, deviceId);
      } else if (!isOnline && device.isPaired) {
        state = state.copyWith(
          connectedDevice: device.copyWith(isPaired: false),
          statusMessage: 'PC (${device.name}) está offline.',
        );
      }
    });
  }

  void _listenIncomingEvents() {
    _wsSubscription = _wsService.messages.listen((msg) async {
      final type = msg['type'];
      final payload = msg['payload'];
      if (type == 'CLIPBOARD_RECEIVED' && payload is Map) {
        final sender = payload['senderDeviceId']?.toString();
        final content = payload['content']?.toString();
        if (sender != deviceId && content != null && content.isNotEmpty) {
          await _clipboardService.setSystemClipboardText(content);
          state = state.copyWith(
            lastSyncedText: content,
            statusMessage: 'Clipboard recebido do Linux e copiado no celular!',
          );
        }
      }
    });
  }

  Future<void> loadSavedDevice() async {
    state = state.copyWith(isConnecting: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final device = Device.fromJson(jsonDecode(raw));

        // Checa se o PC está online antes de conectar
        final isOnline = await _httpService.checkHealth(device.baseUrl);
        if (isOnline) {
          state = state.copyWith(
            connectedDevice: device.copyWith(isPaired: true),
            isConnecting: false,
            statusMessage: 'Conectado a ${device.name}',
          );
          _wsService.connect(device.wsUrl, deviceId);
        } else {
          state = state.copyWith(
            connectedDevice: device.copyWith(isPaired: false),
            isConnecting: false,
            statusMessage: 'PC (${device.name}) está offline. Tentando reconectar...',
          );
        }
        return;
      }
    } catch (_) {}
    state = state.copyWith(isConnecting: false);
  }

  Future<void> setConnectedDevice(Device device) async {
    state = state.copyWith(
      connectedDevice: device.copyWith(isPaired: true),
      statusMessage: 'Conectado a ${device.name}',
    );
    _wsService.connect(device.wsUrl, deviceId);

    // Persiste dispositivo pareado
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(device.toJson()));
    } catch (_) {}
  }

  Future<void> disconnect() async {
    _wsService.disconnect();
    state = state.copyWith(clearDevice: true, statusMessage: 'Desconectado');

    // Remove persistência
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (_) {}
  }

  Future<ClipboardSyncResult> syncCurrentClipboard() async {
    final device = state.connectedDevice;
    if (device == null) {
      const msg = 'Nenhum computador conectado!';
      state = state.copyWith(statusMessage: msg);
      return const ClipboardSyncResult(success: false, errorMessage: msg);
    }

    try {
      final text = await _clipboardService.getSystemClipboardText();
      if (text.trim().isEmpty) {
        const msg = 'Área de transferência do celular está vazia.';
        state = state.copyWith(statusMessage: msg);
        return const ClipboardSyncResult(success: false, errorMessage: msg);
      }

      final response = await _httpService.sendClipboard(
        serverBaseUrl: device.baseUrl,
        content: text,
        deviceId: deviceId,
        token: device.token,
      );

      final data = response.data;
      final contentType = data is Map ? data['contentType']?.toString() : 'text';
      final detectedLang = data is Map ? data['detectedLanguage']?.toString() : null;

      final label = contentType != null && contentType != 'text'
          ? 'Conteúdo [$contentType${detectedLang != null ? ": $detectedLang" : ""}]'
          : 'Texto';

      state = state.copyWith(
        lastSyncedText: text,
        statusMessage: '$label enviado para o Linux com sucesso!',
      );

      return ClipboardSyncResult(
        success: true,
        contentType: contentType,
        detectedLanguage: detectedLang,
      );
    } catch (e) {
      final errorMsg = HttpUploadService.extractErrorMessage(e);
      state = state.copyWith(statusMessage: 'Falha: $errorMsg');
      return ClipboardSyncResult(success: false, errorMessage: errorMsg);
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
