import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/file_payload.dart';
import '../models/transfer_state.dart';
import '../services/http_upload_service.dart';
import '../services/web_socket_service.dart';
import 'home_viewmodel.dart';

class TransferListState {
  final List<TransferItem> transfers;
  final bool isSelectingFile;

  const TransferListState({
    this.transfers = const [],
    this.isSelectingFile = false,
  });

  TransferListState copyWith({
    List<TransferItem>? transfers,
    bool? isSelectingFile,
  }) {
    return TransferListState(
      transfers: transfers ?? this.transfers,
      isSelectingFile: isSelectingFile ?? this.isSelectingFile,
    );
  }
}

class TransferViewModel extends StateNotifier<TransferListState> {
  final HttpUploadService _httpService;
  final WebSocketService _wsService;
  final Ref _ref;

  TransferViewModel({
    required HttpUploadService httpService,
    required WebSocketService wsService,
    required Ref ref,
  })  : _httpService = httpService,
        _wsService = wsService,
        _ref = ref,
        super(const TransferListState()) {
    _listenWebSocket();
  }

  void _listenWebSocket() {
    _wsService.messages.listen((msg) {
      final type = msg['type'];
      final payload = msg['payload'];

      if (type == 'TRANSFER_PROGRESS' && payload != null) {
        final transferId = payload['transferId'];
        final percentage = (payload['percentage'] as num?)?.toDouble() ?? 0.0;
        final bytesWritten = (payload['bytesWritten'] as num?)?.toInt() ?? 0;

        _updateTransfer(transferId, (item) => item.copyWith(
          bytesTransferred: bytesWritten,
          percentage: percentage,
          status: TransferStatus.uploading,
        ));
      } else if (type == 'TRANSFER_COMPLETED' && payload != null) {
        final transferId = payload['transferId'];
        _updateTransfer(transferId, (item) => item.copyWith(
          percentage: 100.0,
          status: TransferStatus.completed,
          completedAt: DateTime.now(),
        ));
      } else if (type == 'TRANSFER_ERROR' && payload != null) {
        final transferId = payload['transferId'];
        final error = payload['error']?.toString();
        _updateTransfer(transferId, (item) => item.copyWith(
          status: TransferStatus.failed,
          errorMessage: error,
        ));
      }
    });
  }

  void _updateTransfer(String id, TransferItem Function(TransferItem item) updater) {
    state = state.copyWith(
      transfers: state.transfers.map((item) => item.id == id ? updater(item) : item).toList(),
    );
  }

  Future<void> pickAndUploadFiles() async {
    final homeState = _ref.read(homeViewModelProvider);
    final device = homeState.connectedDevice;
    if (device == null) return;

    state = state.copyWith(isSelectingFile: true);
    final pickedFiles = await FilePicker.pickFiles();
    state = state.copyWith(isSelectingFile: false);

    if (pickedFiles.isEmpty) return;

    for (final pickedFile in pickedFiles) {
      if (pickedFile.path == null) continue;
      final file = File(pickedFile.path!);
      final size = await file.length();

      final transferId = 'transfer-${DateTime.now().millisecondsSinceEpoch}-${pickedFile.name}';
      final item = TransferItem(
        id: transferId,
        filename: pickedFile.name,
        filePath: pickedFile.path!,
        totalBytes: size,
        status: TransferStatus.hashing,
        startedAt: DateTime.now(),
      );

      state = state.copyWith(transfers: [item, ...state.transfers]);

      // Processa em background
      _executeUpload(transferId, pickedFile.path!, pickedFile.name, size, device.baseUrl, device.token);
    }
  }

  Future<void> uploadFromSharedFiles(List<String> filePaths) async {
    final homeState = _ref.read(homeViewModelProvider);
    final device = homeState.connectedDevice;
    if (device == null || filePaths.isEmpty) return;

    for (final path in filePaths) {
      final file = File(path);
      if (!await file.exists()) continue;

      final filename = path.split(Platform.pathSeparator).last;
      final size = await file.length();
      final transferId = 'share-${DateTime.now().millisecondsSinceEpoch}-$filename';

      final item = TransferItem(
        id: transferId,
        filename: filename,
        filePath: path,
        totalBytes: size,
        status: TransferStatus.hashing,
        startedAt: DateTime.now(),
      );

      state = state.copyWith(transfers: [item, ...state.transfers]);
      _executeUpload(transferId, path, filename, size, device.baseUrl, device.token);
    }
  }

  Future<void> retryTransfer(String transferId) async {
    final matches = state.transfers.where((t) => t.id == transferId);
    if (matches.isEmpty) return;
    final item = matches.first;

    final homeState = _ref.read(homeViewModelProvider);
    final device = homeState.connectedDevice;
    if (device == null) return;

    _updateTransfer(transferId, (t) => t.copyWith(
      status: TransferStatus.hashing,
      bytesTransferred: 0,
      percentage: 0.0,
      errorMessage: null,
    ));

    _executeUpload(transferId, item.filePath, item.filename, item.totalBytes, device.baseUrl, device.token);
  }

  Future<void> _executeUpload(
    String transferId,
    String filePath,
    String filename,
    int sizeBytes,
    String baseUrl,
    String? token,
  ) async {
    try {
      // 1. Calcula hash SHA-256
      final hash = await _httpService.calculateSha256(filePath);

      _updateTransfer(transferId, (i) => i.copyWith(status: TransferStatus.uploading));

      final payload = FilePayload(
        id: transferId,
        name: filename,
        path: filePath,
        sizeBytes: sizeBytes,
        sha256: hash,
      );

      final homeViewModel = _ref.read(homeViewModelProvider.notifier);

      // 2. Upload via HTTP multipart
      await _httpService.uploadFile(
        serverBaseUrl: baseUrl,
        payload: payload,
        deviceId: homeViewModel.deviceId,
        token: token,
        onProgress: (sent, total) {
          final pct = total > 0 ? (sent / total) * 100 : 0.0;
          _updateTransfer(transferId, (i) => i.copyWith(
            bytesTransferred: sent,
            percentage: pct,
          ));
        },
      );

      _updateTransfer(transferId, (i) => i.copyWith(
        status: TransferStatus.completed,
        percentage: 100.0,
        completedAt: DateTime.now(),
      ));
    } catch (e) {
      final errorMsg = HttpUploadService.extractErrorMessage(e);
      _updateTransfer(transferId, (i) => i.copyWith(
        status: TransferStatus.failed,
        errorMessage: errorMsg,
      ));
    }
  }
}

final transferViewModelProvider = StateNotifierProvider<TransferViewModel, TransferListState>((ref) {
  return TransferViewModel(
    httpService: ref.watch(httpUploadServiceProvider),
    wsService: ref.watch(webSocketServiceProvider),
    ref: ref,
  );
});
