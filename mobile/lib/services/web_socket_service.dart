import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  bool get isConnected => _channel != null;

  void connect(String wsUrl, String deviceId) {
    disconnect();

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _subscription = _channel!.stream.listen(
        (message) {
          try {
            final parsed = jsonDecode(message.toString());
            if (parsed is Map<String, dynamic>) {
              _messageController.add(parsed);
            }
          } catch (_) {}
        },
        onError: (err) {
          disconnect();
        },
        onDone: () {
          disconnect();
        },
      );

      // Envia mensagem de identificação inicial
      send('IDENTIFY', {'deviceId': deviceId});
    } catch (_) {
      disconnect();
    }
  }

  void send(String type, Map<String, dynamic> payload) {
    if (_channel != null) {
      final msg = jsonEncode({
        'type': type,
        'payload': payload,
        'timestamp': DateTime.now().toIso8601String(),
      });
      _channel!.sink.add(msg);
    }
  }

  void disconnect() {
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _messageController.close();
  }
}
