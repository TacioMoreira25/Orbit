import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

class ShareIntentService {
  StreamSubscription? _intentSub;
  final _sharedFilesController = StreamController<List<String>>.broadcast();

  Stream<List<String>> get sharedFilesStream => _sharedFilesController.stream;

  void initialize({void Function(List<String> filePaths)? onFilesReceived}) {
    // 1. Arquivos recebidos enquanto o app está aberto na memória ou em segundo plano
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> value) {
        if (value.isNotEmpty) {
          final paths = value.map((f) => f.path).where((p) => p.isNotEmpty).toList();
          if (paths.isNotEmpty) {
            _sharedFilesController.add(paths);
            onFilesReceived?.call(paths);
          }
        }
      },
      onError: (err) {
        // Ignora erros na escuta de streams externas
      },
    );

    // 2. Arquivos recebidos quando o app foi aberto do zero (cold start) pelo menu de compartilhamento
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        final paths = value.map((f) => f.path).where((p) => p.isNotEmpty).toList();
        if (paths.isNotEmpty) {
          _sharedFilesController.add(paths);
          onFilesReceived?.call(paths);
          ReceiveSharingIntent.instance.reset();
        }
      }
    }).catchError((_) {});
  }

  void dispose() {
    _intentSub?.cancel();
    _intentSub = null;
    _sharedFilesController.close();
  }
}

final shareIntentServiceProvider = Provider<ShareIntentService>((ref) {
  final service = ShareIntentService();
  ref.onDispose(() => service.dispose());
  return service;
});
