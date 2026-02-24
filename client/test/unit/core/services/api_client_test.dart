import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sheetshow/core/services/api_client.dart';
import 'package:sheetshow/core/services/error_display_service.dart';

/// Creates an [ApiClient] backed by [MockClient] that returns [statusCode] with [body].
ApiClient _clientWith(int statusCode, {String body = ''}) {
  final mock = MockClient((_) async => http.Response(body, statusCode));
  return ApiClient(tokenStorage: () async => null, httpClient: mock);
}

void main() {
  group('ApiClient._checkStatus via GET', () {
    test('given_200_when_get_then_returnsEmpty', () async {
      final client = _clientWith(200, body: '');
      final result = await client.get('/test');
      expect(result, isEmpty);
    });

    test('given_200WithJson_when_get_then_decodesBody', () async {
      final client = _clientWith(200, body: '{"id":"abc"}');
      final result = await client.get('/test');
      expect(result['id'], 'abc');
    });

    test('given_400_when_get_then_throwsValidationException', () async {
      final client = _clientWith(400);
      expect(() => client.get('/test'), throwsA(isA<ValidationException>()));
    });

    test('given_401_when_get_then_throwsAuthException', () async {
      final client = _clientWith(401);
      expect(() => client.get('/test'), throwsA(isA<AuthException>()));
    });

    test('given_404_when_get_then_throwsAppException', () async {
      final client = _clientWith(404);
      expect(
        () => client.get('/test'),
        throwsA(
          isA<AppException>().having((e) => e.code, 'code', 'not_found'),
        ),
      );
    });

    test('given_409_when_get_then_throwsAppExceptionWithConflictCode', () async {
      final client = _clientWith(409);
      expect(
        () => client.get('/test'),
        throwsA(isA<AppException>().having((e) => e.code, 'code', 'conflict')),
      );
    });

    test('given_429_when_get_then_throwsNetworkException', () async {
      final client = _clientWith(429);
      expect(() => client.get('/test'), throwsA(isA<NetworkException>()));
    });

    test('given_500_when_get_then_throwsNetworkException', () async {
      final client = _clientWith(500);
      expect(() => client.get('/test'), throwsA(isA<NetworkException>()));
    });

    test('given_503_when_get_then_throwsNetworkException', () async {
      final client = _clientWith(503);
      expect(() => client.get('/test'), throwsA(isA<NetworkException>()));
    });

    test('given_302_when_get_then_throwsAppException', () async {
      final client = _clientWith(302);
      expect(() => client.get('/test'), throwsA(isA<AppException>()));
    });
  });

  group('ApiClient POST / PUT / DELETE', () {
    test('given_201_when_post_then_returnsEmptyMap', () async {
      final client = _clientWith(201, body: '');
      final result = await client.post('/test', {'key': 'value'});
      expect(result, isEmpty);
    });

    test('given_200WithJson_when_post_then_decodesBody', () async {
      final mock = MockClient((req) async {
        final body = jsonDecode(req.body) as Map;
        return http.Response('{"echo":"${body["msg"]}"}', 200);
      });
      final client = ApiClient(tokenStorage: () async => null, httpClient: mock);
      final result = await client.post('/echo', {'msg': 'hello'});
      expect(result['echo'], 'hello');
    });

    test('given_200_when_put_then_returnsMap', () async {
      final client = _clientWith(200, body: '{"ok":true}');
      final result = await client.put('/test', {'x': 1});
      expect(result['ok'], isTrue);
    });

    test('given_204_when_delete_then_completes', () async {
      final client = _clientWith(204);
      expect(() => client.delete('/test'), returnsNormally);
    });
  });

  group('ApiClient token injection', () {
    test('given_token_when_get_then_sendsAuthorizationHeader', () async {
      String? capturedAuth;
      final mock = MockClient((req) async {
        capturedAuth = req.headers['Authorization'];
        return http.Response('{}', 200);
      });
      final client = ApiClient(
        tokenStorage: () async => 'my-token',
        httpClient: mock,
      );
      await client.get('/secure');
      expect(capturedAuth, 'Bearer my-token');
    });

    test('given_noToken_when_get_then_noAuthorizationHeader', () async {
      String? capturedAuth;
      final mock = MockClient((req) async {
        capturedAuth = req.headers['Authorization'];
        return http.Response('{}', 200);
      });
      final client = ApiClient(tokenStorage: () async => null, httpClient: mock);
      await client.get('/open');
      expect(capturedAuth, isNull);
    });
  });
}
