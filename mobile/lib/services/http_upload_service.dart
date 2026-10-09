import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import '../models/file_payload.dart';

class HttpUploadService {
  final Dio _dio = Dio();

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
      options: Options(headers: headers),
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
  }) async {
    return await _dio.post(
      '$serverBaseUrl/api/clipboard',
      data: {
        'content': content,
        'senderDeviceId': deviceId,
      },
    );
  }
}
