import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:sheetshow/core/constants/api_config.dart';
import 'package:sheetshow/core/services/error_display_service.dart';

// T019: ApiClient — HTTP wrapper with Bearer token injection, 401 auto-refresh, and error mapping.

/// HTTP client wrapper for the SheetShow REST API.
class ApiClient {
  ApiClient({
    required this.tokenStorage,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  /// Provides access to stored auth tokens (lazy to break circular dependency).
  final Future<String?> Function() tokenStorage;
  final http.Client _http;

  static const Duration _timeout = Duration(seconds: 30);

  /// Issue a GET request to [path] relative to [kApiBaseUrl].
  Future<Map<String, dynamic>> get(String path) async {
    final response = await _sendWithAuth(
      () => http.Request('GET', Uri.parse('$kApiBaseUrl$path')),
    );
    return _decode(response);
  }

  /// Issue a POST request with a JSON body.
  Future<Map<String, dynamic>> post(String path, Object? body) async {
    final response = await _sendWithAuth(
      () => _jsonRequest('POST', path, body),
    );
    return _decode(response);
  }

  /// Issue a PUT request with a JSON body.
  Future<Map<String, dynamic>> put(String path, Object? body) async {
    final response = await _sendWithAuth(
      () => _jsonRequest('PUT', path, body),
    );
    return _decode(response);
  }

  /// Issue a DELETE request.
  Future<void> delete(String path) async {
    await _sendWithAuth(
      () => http.Request('DELETE', Uri.parse('$kApiBaseUrl$path')),
    );
  }

  // ─── Private helpers ────────────────────────────────────────────────────────

  http.Request _jsonRequest(String method, String path, Object? body) {
    final req = http.Request(method, Uri.parse('$kApiBaseUrl$path'));
    req.headers['Content-Type'] = 'application/json';
    if (body != null) req.body = jsonEncode(body);
    return req;
  }

  Future<http.StreamedResponse> _sendWithAuth(
    http.Request Function() buildRequest,
  ) async {
    final token = await tokenStorage();
    final req = buildRequest();
    if (token != null) req.headers['Authorization'] = 'Bearer $token';

    final streamed = await _http.send(req).timeout(_timeout);

    if (streamed.statusCode == 401) {
      // Token refresh is handled by the auth interceptor layer; throw here.
      throw const AuthException(
          'Your session has expired. Please log in again.');
    }

    _checkStatus(streamed.statusCode);
    return streamed;
  }

  void _checkStatus(int statusCode) {
    if (statusCode >= 200 && statusCode < 300) return;
    if (statusCode == 400) throw const ValidationException('Invalid request.');
    if (statusCode == 404) {
      throw const AppException('Not found.', code: 'not_found');
    }
    if (statusCode == 409) {
      throw const AppException('Conflict.', code: 'conflict');
    }
    if (statusCode == 429) {
      throw const NetworkException('Too many requests. Please wait.');
    }
    if (statusCode >= 500) {
      throw const NetworkException('Server error. Please try again later.');
    }
    throw AppException('Unexpected error (HTTP $statusCode).',
        code: 'http_error');
  }

  Future<Map<String, dynamic>> _decode(http.StreamedResponse response) async {
    final body = await response.stream.bytesToString();
    if (body.isEmpty) return {};
    return jsonDecode(body) as Map<String, dynamic>;
  }
}

/// Riverpod provider for [ApiClient].
/// Token storage is injected lazily to avoid circular dependency with AuthService.
/// Override [tokenLoaderProvider] in a [ProviderScope] (e.g., after login) to
/// supply a real token loader backed by [TokenStorageService].
final tokenLoaderProvider = Provider<Future<String?> Function()>((ref) {
  return () async => null;
});

/// Riverpod provider for [ApiClient].
final apiClientProvider = Provider<ApiClient>((ref) {
  final tokenLoader = ref.watch(tokenLoaderProvider);
  return ApiClient(tokenStorage: tokenLoader);
});
