import 'dart:io';
import 'dart:isolate';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import '../models/file_payload.dart';

class HttpUploadService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  static String extractErrorMessage(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
          return 'Tempo limite esgotado ao tentar conectar ao servidor.';
        case DioExceptionType.sendTimeout:
          return 'Tempo limite esgotado durante o envio dos dados.';
        case DioExceptionType.receiveTimeout:
          return 'O servidor demorou muito para responder.';
        case DioExceptionType.connectionError:
          return 'Não foi possível conectar. Verifique se o IP está correto e se o servidor Orbit está rodando no Linux.';
        case DioExceptionType.badResponse:
          final data = error.response?.data;
          if (data is Map) {
            final serverMsg = data['error'] ?? data['message'];
            if (serverMsg != null && serverMsg.toString().isNotEmpty) {
              return serverMsg.toString();
            }
          }
          if (error.response?.statusCode == 401) {
            return 'PIN incorreto, expirado ou não autorizado.';
          }
          if (error.response?.statusCode == 404) {
            return 'Recurso não encontrado no servidor.';
          }
          return 'Erro no servidor (${error.response?.statusCode}): ${error.response?.statusMessage ?? 'Falha desconhecida'}';
        case DioExceptionType.cancel:
          return 'Transferência cancelada pelo usuário.';
        default:
          return 'Erro de comunicação de rede: ${error.message ?? 'Desconhecido'}';
      }
    }
    return error.toString();
  }

  Future<bool> checkHealth(String serverBaseUrl) async {
    try {
      final response = await _dio.get(
        '$serverBaseUrl/health',
        options: Options(
          sendTimeout: const Duration(seconds: 2),
          receiveTimeout: const Duration(seconds: 2),
        ),
      );
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map) {
          return data['status'] == 'ok';
        }
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Calcula o SHA-256 em um Isolate separado para nunca travar a UI de 120Hz em arquivos de múltiplos GBs
  Future<String> calculateSha256(String filePath) async {
    return await Isolate.run(() async {
      final file = File(filePath);
      final output = await sha256.bind(file.openRead()).first;
      return output.toString();
    });
  }

  Future<Response> uploadFile({
    required String serverBaseUrl,
    required FilePayload payload,
    required String deviceId,
    String? token,
    CancelToken? cancelToken,
    void Function(int sentBytes, int totalBytes)? onProgress,
  }) async {
    final file = File(payload.path);
    final fileName = payload.name;

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: fileName,
      ),
    });

    final headers = <String, dynamic>{
      'x-transfer-id': payload.id,
      'x-device-id': deviceId,
      'x-file-size': payload.sizeBytes.toString(),
    };

    if (payload.sha256 != null) {
      headers['x-file-hash'] = payload.sha256!;
    }

    if (token != null) {
      headers['authorization'] = 'Bearer $token';
    }

    return await _dio.post(
      '$serverBaseUrl/api/upload',
      data: formData,
      cancelToken: cancelToken,
      options: Options(
        headers: headers,
        receiveTimeout: const Duration(minutes: 10), // Permite arquivos grandes
      ),
      onSendProgress: onProgress,
    );
  }

  Future<Response> pairDevice({
    required String serverBaseUrl,
    required String pin,
    required String deviceName,
  }) async {
    return await _dio.post(
      '$serverBaseUrl/api/pair',
      data: {
        'pin': pin,
        'deviceName': deviceName,
        'platform': 'android',
      },
    );
  }

  Future<Response> sendClipboard({
    required String serverBaseUrl,
    required String content,
    required String deviceId,
    String? token,
  }) async {
    final headers = <String, dynamic>{};
    if (token != null) {
      headers['authorization'] = 'Bearer $token';
    }

    return await _dio.post(
      '$serverBaseUrl/api/clipboard',
      data: {
        'content': content,
        'senderDeviceId': deviceId,
      },
      options: Options(headers: headers),
    );
  }

  Future<Response> downloadFile({
    required String downloadUrl,
    required String savePath,
    String? token,
    CancelToken? cancelToken,
    void Function(int receivedBytes, int totalBytes)? onProgress,
  }) async {
    final headers = <String, dynamic>{};
    if (token != null) {
      headers['authorization'] = 'Bearer $token';
    }

    return await _dio.download(
      downloadUrl,
      savePath,
      cancelToken: cancelToken,
      options: Options(
        headers: headers,
        receiveTimeout: const Duration(minutes: 10),
      ),
      onReceiveProgress: onProgress,
    );
  }

  Future<List<Map<String, dynamic>>> fetchSharedFiles({
    required String serverBaseUrl,
    String? token,
  }) async {
    try {
      final headers = <String, dynamic>{};
      if (token != null) {
        headers['authorization'] = 'Bearer $token';
      }
      final response = await _dio.get(
        '$serverBaseUrl/api/files',
        options: Options(headers: headers),
      );
      final data = response.data;
      if (data is Map && data['files'] is List) {
        return List<Map<String, dynamic>>.from(
          (data['files'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
        );
      }
    } catch (_) {}
    return const [];
  }
}
