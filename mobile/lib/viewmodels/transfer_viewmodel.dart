import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device.dart';
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
  StreamSubscription? _wsSubscription;
  final Map<String, CancelToken> _cancelTokens = {};

  final Set<String> _handledRemoteFileIds = {};
  static const String _handledFilesStorageKey = 'orbit_handled_remote_files';

  TransferViewModel({
    required HttpUploadService httpService,
    required WebSocketService wsService,
    required Ref ref,
  })  : _httpService = httpService,
        _wsService = wsService,
        _ref = ref,
        super(const TransferListState()) {
    _loadHandledFileIds();
    _listenWebSocket();
  }

  Future<void> _loadHandledFileIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_handledFilesStorageKey);
      if (saved != null) {
        _handledRemoteFileIds.addAll(saved);
      }
    } catch (_) {}
  }

  Future<void> _markFileHandled(String fileId) async {
    _handledRemoteFileIds.add(fileId);
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _handledRemoteFileIds.toList();
      if (list.length > 100) {
        list.removeRange(0, list.length - 100);
      }
      await prefs.setStringList(_handledFilesStorageKey, list);
    } catch (_) {}
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    for (final token in _cancelTokens.values) {
      if (!token.isCancelled) token.cancel();
    }
    _cancelTokens.clear();
    super.dispose();
  }

  void _listenWebSocket() {
    _wsSubscription = _wsService.messages.listen((msg) {
      final type = msg['type'];
      final payload = msg['payload'];

      if (type == 'TRANSFER_PROGRESS' && payload != null) {
        final transferId = payload['transferId'];
        final percentage = (payload['percentage'] as num?)?.toDouble() ?? 0.0;
        final bytesWritten = (payload['bytesWritten'] as num?)?.toInt() ?? 0;
        final speedBytesPerSec = (payload['speedBytesPerSec'] as num?)?.toDouble();
        final etaSeconds = (payload['etaSeconds'] as num?)?.toInt();

        _updateTransfer(transferId, (item) => item.copyWith(
          bytesTransferred: bytesWritten,
          percentage: percentage,
          speedBytesPerSec: speedBytesPerSec ?? item.speedBytesPerSec,
          etaSeconds: etaSeconds ?? item.etaSeconds,
          status: TransferStatus.uploading,
        ));
      } else if (type == 'TRANSFER_COMPLETED' && payload != null) {
        final transferId = payload['transferId'];
        _updateTransfer(transferId, (item) => item.copyWith(
          percentage: 100.0,
          etaSeconds: 0,
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
      } else if (type == 'FILE_AVAILABLE' && payload != null) {
        final fileId = payload['fileId']?.toString() ?? 'pc-file';
        final filename = payload['filename']?.toString() ?? 'orbit-download.bin';
        final sizeBytes = (payload['sizeBytes'] as num?)?.toInt() ?? 0;
        final expectedSha256 = payload['sha256']?.toString();
        final downloadPath = payload['downloadPath']?.toString() ?? '/api/download/$fileId';

        _receiveFileFromPc(
          fileId: fileId,
          filename: filename,
          sizeBytes: sizeBytes,
          expectedSha256: expectedSha256,
          downloadPath: downloadPath,
        );
      }
    });
  }

  void _updateProgressMetrics({
    required String transferId,
    required int transferredBytes,
    required int totalBytes,
    required DateTime startTime,
  }) {
    final pct = totalBytes > 0 ? (transferredBytes / totalBytes) * 100 : 0.0;
    final elapsedSec = DateTime.now().difference(startTime).inMilliseconds / 1000.0;
    final speed = elapsedSec > 0.05 ? transferredBytes / elapsedSec : 0.0;
    final remaining = totalBytes - transferredBytes;
    final eta = (speed > 0 && remaining > 0) ? (remaining / speed).ceil() : 0;

    _updateTransfer(transferId, (i) => i.copyWith(
      bytesTransferred: transferredBytes,
      totalBytes: totalBytes,
      percentage: pct,
      speedBytesPerSec: speed,
      etaSeconds: eta,
    ));
  }

  Future<void> checkPendingFilesFromPc() async {
    await _loadHandledFileIds();
    final device = _ref.read(homeViewModelProvider).connectedDevice;
    if (device == null) return;

    final files = await _httpService.fetchSharedFiles(
      serverBaseUrl: device.baseUrl,
      token: device.token,
    );

    for (final file in files) {
      final fileId = file['fileId']?.toString();
      if (fileId == null || _handledRemoteFileIds.contains(fileId)) continue;

      final filename = file['filename']?.toString() ?? 'orbit-download.bin';
      final sizeBytes = (file['sizeBytes'] as num?)?.toInt() ?? 0;
      final expectedSha256 = file['sha256']?.toString();

      await _receiveFileFromPc(
        fileId: fileId,
        filename: filename,
        sizeBytes: sizeBytes,
        expectedSha256: expectedSha256,
        downloadPath: '/api/download/$fileId',
      );
    }
  }

  void clearFinishedTransfers() {
    state = state.copyWith(
      transfers: state.transfers
          .where((t) =>
              t.status == TransferStatus.uploading ||
              t.status == TransferStatus.hashing ||
              t.status == TransferStatus.verifying)
          .toList(),
    );
  }

  Future<void> _receiveFileFromPc({
    required String fileId,
    required String filename,
    required int sizeBytes,
    required String downloadPath,
    String? expectedSha256,
  }) async {
    if (_handledRemoteFileIds.contains(fileId)) return;
    final device = _ref.read(homeViewModelProvider).connectedDevice;
    if (device == null) return;

    await _markFileHandled(fileId);
    final transferId = 'download-$fileId';
    final androidDownloadDir = Directory('/storage/emulated/0/Download');
    final targetDir = await androidDownloadDir.exists() ? androidDownloadDir : Directory.systemTemp;
    final savePath = '${targetDir.path}${Platform.pathSeparator}$filename';

    final startTime = DateTime.now();
    final item = TransferItem(
      id: transferId,
      filename: '⬇ $filename',
      filePath: savePath,
      totalBytes: sizeBytes,
      status: TransferStatus.uploading,
      startedAt: startTime,
    );

    state = state.copyWith(transfers: [item, ...state.transfers]);

    final cancelToken = CancelToken();
    _cancelTokens[transferId] = cancelToken;

    try {
      await _httpService.downloadFile(
        downloadUrl: '${device.baseUrl}$downloadPath',
        savePath: savePath,
        token: device.token,
        cancelToken: cancelToken,
        onProgress: (received, total) {
          final effectiveTotal = total > 0 ? total : sizeBytes;
          _updateProgressMetrics(
            transferId: transferId,
            transferredBytes: received,
            totalBytes: effectiveTotal,
            startTime: startTime,
          );
        },
      );

      if (expectedSha256 != null && expectedSha256.isNotEmpty) {
        _updateTransfer(transferId, (i) => i.copyWith(status: TransferStatus.verifying));
        final calcHash = await _httpService.calculateSha256(savePath);
        if (calcHash.toLowerCase() != expectedSha256.toLowerCase()) {
          throw Exception('Falha de integridade SHA-256 no arquivo recebido do PC.');
        }
      }

      _cancelTokens.remove(transferId);
      _updateTransfer(transferId, (i) => i.copyWith(
        status: TransferStatus.completed,
        percentage: 100.0,
        etaSeconds: 0,
        completedAt: DateTime.now(),
      ));
    } catch (e) {
      _cancelTokens.remove(transferId);
      final errorMsg = HttpUploadService.extractErrorMessage(e);
      _updateTransfer(transferId, (i) => i.copyWith(
        status: TransferStatus.failed,
        errorMessage: errorMsg,
      ));
    }
  }

  void _updateTransfer(String id, TransferItem Function(TransferItem item) updater) {
    state = state.copyWith(
      transfers: state.transfers.map((item) => item.id == id ? updater(item) : item).toList(),
    );
  }

  void cancelTransfer(String transferId) {
    final token = _cancelTokens.remove(transferId);
    if (token != null && !token.isCancelled) {
      token.cancel('Cancelado pelo usuário');
    }
    _updateTransfer(transferId, (item) => item.copyWith(
      status: TransferStatus.cancelled,
      errorMessage: 'Transferência cancelada.',
    ));
  }

  void _enqueueAndStartUpload({
    required String prefix,
    required String filePath,
    required String filename,
    required int sizeBytes,
    required Device device,
  }) {
    final transferId = '$prefix-${DateTime.now().millisecondsSinceEpoch}-$filename';
    final item = TransferItem(
      id: transferId,
      filename: filename,
      filePath: filePath,
      totalBytes: sizeBytes,
      status: TransferStatus.hashing,
      startedAt: DateTime.now(),
    );

    state = state.copyWith(transfers: [item, ...state.transfers]);
    _executeUpload(transferId, filePath, filename, sizeBytes, device.baseUrl, device.token);
  }

  Future<void> pickAndUploadFiles() async {
    final device = _ref.read(homeViewModelProvider).connectedDevice;
    if (device == null) return;

    state = state.copyWith(isSelectingFile: true);
    final pickedFiles = await FilePicker.pickFiles();
    state = state.copyWith(isSelectingFile: false);

    if (pickedFiles.isEmpty) return;

    for (final pickedFile in pickedFiles) {
      if (pickedFile.path == null) continue;
      final file = File(pickedFile.path!);
      final size = await file.length();

      _enqueueAndStartUpload(
        prefix: 'transfer',
        filePath: pickedFile.path!,
        filename: pickedFile.name,
        sizeBytes: size,
        device: device,
      );
    }
  }

  Future<void> uploadFromSharedFiles(List<String> filePaths) async {
    final device = _ref.read(homeViewModelProvider).connectedDevice;
    if (device == null || filePaths.isEmpty) return;

    for (final path in filePaths) {
      final file = File(path);
      if (!await file.exists()) continue;

      final filename = path.split(Platform.pathSeparator).last;
      final size = await file.length();

      _enqueueAndStartUpload(
        prefix: 'share',
        filePath: path,
        filename: filename,
        sizeBytes: size,
        device: device,
      );
    }
  }

  Future<void> retryTransfer(String transferId) async {
    final matches = state.transfers.where((t) => t.id == transferId);
    if (matches.isEmpty) return;
    final item = matches.first;

    final device = _ref.read(homeViewModelProvider).connectedDevice;
    if (device == null) return;

    _updateTransfer(transferId, (t) => t.copyWith(
      status: TransferStatus.hashing,
      bytesTransferred: 0,
      percentage: 0.0,
      speedBytesPerSec: 0.0,
      etaSeconds: null,
      errorMessage: null,
      startedAt: DateTime.now(),
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
    final cancelToken = CancelToken();
    _cancelTokens[transferId] = cancelToken;

    try {
      final hash = await _httpService.calculateSha256(filePath);
      if (cancelToken.isCancelled) return;

      final uploadStartTime = DateTime.now();
      _updateTransfer(transferId, (i) => i.copyWith(
        status: TransferStatus.uploading,
        startedAt: uploadStartTime,
      ));

      final payload = FilePayload(
        id: transferId,
        name: filename,
        path: filePath,
        sizeBytes: sizeBytes,
        sha256: hash,
      );

      final homeViewModel = _ref.read(homeViewModelProvider.notifier);

      await _httpService.uploadFile(
        serverBaseUrl: baseUrl,
        payload: payload,
        deviceId: homeViewModel.deviceId,
        token: token,
        cancelToken: cancelToken,
        onProgress: (sent, total) {
          _updateProgressMetrics(
            transferId: transferId,
            transferredBytes: sent,
            totalBytes: total,
            startTime: uploadStartTime,
          );
        },
      );

      _cancelTokens.remove(transferId);
      _updateTransfer(transferId, (i) => i.copyWith(
        status: TransferStatus.completed,
        percentage: 100.0,
        etaSeconds: 0,
        completedAt: DateTime.now(),
      ));
    } catch (e) {
      _cancelTokens.remove(transferId);
      if (e is DioException && e.type == DioExceptionType.cancel) {
        _updateTransfer(transferId, (i) => i.copyWith(
          status: TransferStatus.cancelled,
          errorMessage: 'Transferência cancelada.',
        ));
        return;
      }
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
