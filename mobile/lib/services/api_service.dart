import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/room_state.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiService {
  ApiService({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<CreateRoomResponse> createRoom(String username) async {
    final response = await _client.post(
      _uri('/api/rooms'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username}),
    );

    if (response.statusCode == 201) {
      return CreateRoomResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw _parseError(response);
  }

  Future<Map<String, dynamic>> getRoom(String roomId) async {
    final response = await _client.get(_uri('/api/rooms/$roomId'));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw _parseError(response);
  }

  Future<UploadVideoResponse> uploadVideo(String roomId, File videoFile) async {
    final request = http.MultipartRequest(
      'POST',
      _uri('/api/rooms/$roomId/video'),
    );
    request.files.add(
      await http.MultipartFile.fromPath('video', videoFile.path),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 201) {
      return UploadVideoResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw _parseError(response);
  }

  String resolveVideoUrl(String? relativePath) {
    if (relativePath == null) return '';
    if (relativePath.startsWith('http')) return relativePath;
    return '$baseUrl$relativePath';
  }

  String videoUrlWithVersion(String url, int version) {
    if (version <= 0) return url;
    final uri = Uri.parse(url);
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      'v': version.toString(),
    }).toString();
  }

  ApiException _parseError(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiException(
        body['message'] as String? ?? 'Request failed',
        statusCode: response.statusCode,
      );
    } catch (_) {
      return ApiException('Request failed', statusCode: response.statusCode);
    }
  }

  void dispose() => _client.close();
}
