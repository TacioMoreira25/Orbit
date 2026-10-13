import 'dart:io';
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
          return 'Operação cancelada.';
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
        options: Options(receiveTimeout: const Duration(seconds: 3)),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<String> calculateSha256(String filePath) async {
    final file = File(filePath);
    final output = await sha256.bind(file.openRead()).first;
    return output.toString();
  }

  Future<Response> uploadFile({
    required String serverBaseUrl,
    required FilePayload payload,
    required String deviceId,
    String? token,
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
}
