import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  String? _lastWsUrl;
  String? _lastDeviceId;
  bool _manualDisconnect = false;
  int _retryCount = 0;

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  bool get isConnected => _channel != null;

  void connect(String wsUrl, String deviceId) {
    _manualDisconnect = false;
    _lastWsUrl = wsUrl;
    _lastDeviceId = deviceId;
    _reconnectTimer?.cancel();
    _openChannel();
  }

  void _openChannel() {
    _closeCurrentSocket();
    final wsUrl = _lastWsUrl;
    final deviceId = _lastDeviceId;
    if (wsUrl == null || deviceId == null) return;

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _retryCount = 0;

      _subscription = _channel!.stream.listen(
        (message) {
          try {
            final parsed = jsonDecode(message.toString());
            if (parsed is Map<String, dynamic>) {
              _messageController.add(parsed);
            }
          } catch (_) {}
        },
        onError: (_) {
          _scheduleReconnect();
        },
        onDone: () {
          _scheduleReconnect();
        },
      );

      // Envia mensagem de identificação inicial
      send('IDENTIFY', {'deviceId': deviceId});

      // Mantém conexão viva (heartbeat a cada 15s)
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        send('PING', {'deviceId': deviceId});
      });
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _closeCurrentSocket();
    if (_manualDisconnect || _lastWsUrl == null) return;

    _reconnectTimer?.cancel();
    final delaySeconds = (_retryCount < 3) ? 2 : 5;
    _retryCount++;
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!_manualDisconnect) {
        _openChannel();
      }
    });
  }

  void send(String type, Map<String, dynamic> payload) {
    if (_channel != null) {
      try {
        final msg = jsonEncode({
          'type': type,
          'payload': payload,
          'timestamp': DateTime.now().toIso8601String(),
        });
        _channel!.sink.add(msg);
      } catch (_) {
        _scheduleReconnect();
      }
    }
  }

  void _closeCurrentSocket() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _subscription?.cancel();
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  void disconnect() {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _closeCurrentSocket();
  }

  void dispose() {
    disconnect();
    _messageController.close();
  }
}
