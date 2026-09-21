import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

enum ApiExceptionType {
  deviceNotFound,
  networkUnreachable,
  apiUnavailable,
  requestTimeout,
  invalidResponse,
  acquisitionNotReady,
  serverError,
  unknown,
}

class ApiException implements Exception {
  final ApiExceptionType type;
  final String message;
  final int? statusCode;

  const ApiException({
    required this.type,
    required this.message,
    this.statusCode,
  });

  @override
  String toString() => 'ApiException [$type]: $message (Status: $statusCode)';
}

class ApiClient {
  String baseUrl;
  final http.Client _client;

  ApiClient({
    this.baseUrl = 'http://hemopi.local:8000',
    http.Client? client,
  }) : _client = client ?? http.Client();

  Future<dynamic> get(String endpoint) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    try {
      final response = await _client.get(uri).timeout(const Duration(seconds: 5));
      return _handleResponse(response);
    } on TimeoutException {
      throw const ApiException(
        type: ApiExceptionType.requestTimeout,
        message: 'Request to HemoPi timed out.',
      );
    } on SocketException catch (e) {
      throw ApiException(
        type: ApiExceptionType.deviceNotFound,
        message: 'HemoPi device not found or network unreachable: ${e.message}',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        type: ApiExceptionType.unknown,
        message: e.toString(),
      );
    }
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
      return _handleResponse(response);
    } on TimeoutException {
      throw const ApiException(
        type: ApiExceptionType.requestTimeout,
        message: 'Request to HemoPi timed out.',
      );
    } on SocketException catch (e) {
      throw ApiException(
        type: ApiExceptionType.deviceNotFound,
        message: 'HemoPi device not found or network unreachable: ${e.message}',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        type: ApiExceptionType.unknown,
        message: e.toString(),
      );
    }
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      try {
        return jsonDecode(response.body);
      } catch (e) {
        throw ApiException(
          type: ApiExceptionType.invalidResponse,
          message: 'Failed to parse JSON response: $e',
          statusCode: response.statusCode,
        );
      }
    } else {
      String msg = response.body;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded.containsKey('detail')) {
          msg = decoded['detail'];
        }
      } catch (_) {}

      if (response.statusCode == 409) {
        throw ApiException(
          type: ApiExceptionType.acquisitionNotReady,
          message: msg,
          statusCode: 409,
        );
      } else if (response.statusCode == 404) {
        throw ApiException(
          type: ApiExceptionType.apiUnavailable,
          message: msg,
          statusCode: 404,
        );
      } else if (response.statusCode >= 500) {
        throw ApiException(
          type: ApiExceptionType.serverError,
          message: msg,
          statusCode: response.statusCode,
        );
      } else {
        throw ApiException(
          type: ApiExceptionType.unknown,
          message: msg,
          statusCode: response.statusCode,
        );
      }
    }
  }
}
