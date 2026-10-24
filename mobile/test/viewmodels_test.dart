import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:orbit/models/device.dart';
import 'package:orbit/services/clipboard_service.dart';
import 'package:orbit/services/http_upload_service.dart';
import 'package:orbit/services/web_socket_service.dart';
import 'package:orbit/viewmodels/home_viewmodel.dart';
import 'package:orbit/viewmodels/pairing_viewmodel.dart';

// --- Mocks para os Serviços ---

class MockHttpUploadService extends HttpUploadService {
  bool shouldSucceedPair = true;
  String? mockToken = 'mock-bearer-token-123';
  String? mockServerName = 'Test-Linux-PC';
  String? pairErrorMessage;
  bool isHealthOk = true;

  @override
  Future<bool> checkHealth(String serverBaseUrl) async {
    return isHealthOk;
  }

  @override
  Future<Response> pairDevice({
    required String serverBaseUrl,
    required String pin,
    required String deviceName,
  }) async {
    if (shouldSucceedPair && pin == '1234') {
      return Response(
        requestOptions: RequestOptions(path: '/api/pair'),
        statusCode: 200,
        data: {
          'success': true,
          'token': mockToken,
          'serverDeviceName': mockServerName,
          'message': 'Dispositivo pareado com sucesso!',
        },
      );
    } else {
      return Response(
        requestOptions: RequestOptions(path: '/api/pair'),
        statusCode: 401,
        data: {
          'error': pairErrorMessage ?? 'PIN incorreto ou expirado.',
          'code': 'INVALID_PIN',
        },
      );
    }
  }

  @override
  Future<Response> sendClipboard({
    required String serverBaseUrl,
    required String content,
    required String deviceId,
    String? token,
  }) async {
    return Response(
      requestOptions: RequestOptions(path: '/api/clipboard'),
      statusCode: 200,
      data: {
        'id': 'clipboard-1',
        'contentType': 'text',
        'appliedToSystemClipboard': true,
      },
    );
  }
}

class MockWebSocketService extends WebSocketService {
  String? lastConnectedUrl;
  bool wasDisconnected = false;

  @override
  void connect(String wsUrl, String deviceId) {
    lastConnectedUrl = wsUrl;
    wasDisconnected = false;
  }

  @override
  void disconnect() {
    wasDisconnected = true;
    lastConnectedUrl = null;
  }
}

class MockClipboardService extends MobileClipboardService {
  String clipboardContent = '';

  @override
  Future<String> getSystemClipboardText() async {
    return clipboardContent;
  }

  @override
  Future<void> setSystemClipboardText(String text) async {
    clipboardContent = text;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PairingViewModel Unit Tests', () {
    late MockHttpUploadService mockHttp;
    late MockWebSocketService mockWs;
    late MockClipboardService mockClipboard;
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockHttp = MockHttpUploadService();
      mockWs = MockWebSocketService();
      mockClipboard = MockClipboardService();

      container = ProviderContainer(
        overrides: [
          httpUploadServiceProvider.overrideWithValue(mockHttp),
          webSocketServiceProvider.overrideWithValue(mockWs),
          mobileClipboardServiceProvider.overrideWithValue(mockClipboard),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('Initial state is default and not loading', () {
      final viewModel = container.read(pairingViewModelProvider.notifier);
      final state = container.read(pairingViewModelProvider);

      expect(state.isLoading, false);
      expect(state.isSuccess, false);
      expect(state.errorMessage, isNull);
      expect(viewModel.state.isLoading, false);
    });

    test('pairWithManualInput succeeds with correct PIN', () async {
      final viewModel = container.read(pairingViewModelProvider.notifier);

      final success = await viewModel.pairWithManualInput('192.168.1.100', 3000, '1234');

      expect(success, true);
      expect(viewModel.state.isLoading, false);
      expect(viewModel.state.isSuccess, true);
      expect(viewModel.state.errorMessage, isNull);

      final homeState = container.read(homeViewModelProvider);
      expect(homeState.connectedDevice, isNotNull);
      expect(homeState.connectedDevice!.host, '192.168.1.100');
      expect(homeState.connectedDevice!.token, 'mock-bearer-token-123');
      expect(homeState.connectedDevice!.isPaired, true);
    });

    test('pairWithManualInput fails with incorrect PIN and updates errorMessage (RF-10)', () async {
      final viewModel = container.read(pairingViewModelProvider.notifier);

      final success = await viewModel.pairWithManualInput('192.168.1.100', 3000, '9999');

      expect(success, false);
      expect(viewModel.state.isLoading, false);
      expect(viewModel.state.isSuccess, false);
      expect(viewModel.state.errorMessage, contains('PIN incorreto'));

      final homeState = container.read(homeViewModelProvider);
      expect(homeState.connectedDevice, isNull);
    });

    test('pairWithQrCodePayload parses QR JSON and pairs device', () async {
      final viewModel = container.read(pairingViewModelProvider.notifier);

      final qrPayload = jsonEncode({
        'ip': '10.0.0.50',
        'port': 3000,
        'pin': '1234',
        'deviceName': 'Office-Linux',
        'token': 'qr-token',
      });

      final success = await viewModel.pairWithQrCodePayload(qrPayload);

      expect(success, true);
      expect(viewModel.state.isSuccess, true);

      final homeState = container.read(homeViewModelProvider);
      expect(homeState.connectedDevice!.host, '10.0.0.50');
      expect(homeState.connectedDevice!.name, 'Office-Linux');
    });

    test('pairWithQrCodePayload handles malformed JSON gracefully', () async {
      final viewModel = container.read(pairingViewModelProvider.notifier);

      final success = await viewModel.pairWithQrCodePayload('invalid-json');

      expect(success, false);
      expect(viewModel.state.isLoading, false);
      expect(viewModel.state.errorMessage, isNotNull);
    });
  });

  group('HomeViewModel Unit Tests', () {
    late MockHttpUploadService mockHttp;
    late MockWebSocketService mockWs;
    late MockClipboardService mockClipboard;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockHttp = MockHttpUploadService();
      mockWs = MockWebSocketService();
      mockClipboard = MockClipboardService();
    });

    test('setConnectedDevice updates state, connects WS, and persists to SharedPreferences', () async {
      final vm = HomeViewModel(
        httpService: mockHttp,
        wsService: mockWs,
        clipboardService: mockClipboard,
      );

      const device = Device(
        id: 'linux-1',
        name: 'My-PC',
        host: '192.168.0.10',
        port: 3000,
        token: 'token-abc',
        isPaired: true,
      );

      await vm.setConnectedDevice(device);

      expect(vm.state.connectedDevice, isNotNull);
      expect(vm.state.connectedDevice!.name, 'My-PC');
      expect(vm.state.connectedDevice!.isPaired, true);
      expect(mockWs.lastConnectedUrl, 'ws://192.168.0.10:3000/ws');

      // Verify persistence in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString('orbit_saved_device');
      expect(savedJson, isNotNull);
      expect(savedJson, contains('192.168.0.10'));
    });

    test('disconnect clears device, disconnects WS, and clears persistence', () async {
      final vm = HomeViewModel(
        httpService: mockHttp,
        wsService: mockWs,
        clipboardService: mockClipboard,
      );

      const device = Device(
        id: 'linux-1',
        name: 'My-PC',
        host: '192.168.0.10',
        port: 3000,
        isPaired: true,
      );

      await vm.setConnectedDevice(device);
      expect(vm.state.connectedDevice, isNotNull);

      await vm.disconnect();
      expect(vm.state.connectedDevice, isNull);
      expect(mockWs.wasDisconnected, true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('orbit_saved_device'), isNull);
    });

    test('loadSavedDevice restores session when device is online (RF-08)', () async {
      final savedDeviceMap = {
        'id': 'linux-server',
        'name': 'Saved-Linux',
        'host': '192.168.1.50',
        'port': 3000,
        'token': 'persisted-token-xyz',
        'isPaired': true,
      };

      SharedPreferences.setMockInitialValues({
        'orbit_saved_device': jsonEncode(savedDeviceMap),
      });

      mockHttp.isHealthOk = true;

      final vm = HomeViewModel(
        httpService: mockHttp,
        wsService: mockWs,
        clipboardService: mockClipboard,
      );

      await vm.loadSavedDevice();

      expect(vm.state.connectedDevice, isNotNull);
      expect(vm.state.connectedDevice!.name, 'Saved-Linux');
      expect(vm.state.connectedDevice!.isPaired, true);
      expect(mockWs.lastConnectedUrl, 'ws://192.168.1.50:3000/ws');
    });

    test('syncCurrentClipboard returns error when no device is connected', () async {
      final vm = HomeViewModel(
        httpService: mockHttp,
        wsService: mockWs,
        clipboardService: mockClipboard,
      );

      final result = await vm.syncCurrentClipboard();

      expect(result.success, false);
      expect(result.errorMessage, contains('Nenhum computador conectado'));
    });

    test('syncCurrentClipboard syncs successfully when text is present', () async {
      final vm = HomeViewModel(
        httpService: mockHttp,
        wsService: mockWs,
        clipboardService: mockClipboard,
      );

      const device = Device(
        id: 'linux-1',
        name: 'My-PC',
        host: '192.168.0.10',
        port: 3000,
        token: 'token-abc',
        isPaired: true,
      );
      await vm.setConnectedDevice(device);

      mockClipboard.clipboardContent = 'https://orbit.local/share';

      final result = await vm.syncCurrentClipboard();

      expect(result.success, true);
      expect(vm.state.lastSyncedText, 'https://orbit.local/share');
    });
  });
}
