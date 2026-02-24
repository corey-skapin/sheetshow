import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sheetshow/core/services/api_client.dart';
import 'package:sheetshow/features/auth/models/auth_token.dart';
import 'package:sheetshow/features/auth/services/auth_service.dart';
import 'package:sheetshow/features/auth/services/token_storage_service.dart';

// ── Fake TokenStorageService ──────────────────────────────────────────────────
class _FakeTokenStorage extends TokenStorageService {
  _FakeTokenStorage() : super(const FlutterSecureStorage());

  AuthToken? _stored;

  @override
  Future<void> saveTokens(AuthToken token) async => _stored = token;

  @override
  Future<AuthToken?> loadTokens() async => _stored;

  @override
  Future<void> clearTokens() async => _stored = null;

  @override
  Future<String?> getAccessToken() async => _stored?.accessToken;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

ApiClient _apiWith(int statusCode, Map<String, dynamic> body) {
  final mock = MockClient((_) async => http.Response(jsonEncode(body), statusCode));
  return ApiClient(tokenStorage: () async => null, httpClient: mock);
}

AuthService _service(ApiClient apiClient) =>
    AuthService(apiClient: apiClient, tokenStorage: _FakeTokenStorage());

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService initial state', () {
    test('given_newService_when_created_then_notAuthenticated', () {
      final s = _service(_apiWith(200, {}));
      expect(s.state.isAuthenticated, isFalse);
      expect(s.state.isLoading, isFalse);
      expect(s.state.error, isNull);
    });
  });

  group('AuthService.login', () {
    test('given_validCredentials_when_login_then_isAuthenticated', () async {
      final s = _service(_apiWith(200, {
        'accessToken': 'at',
        'refreshToken': 'rt',
        'userId': 'u-1',
        'email': 'alice@test.com',
        'displayName': 'Alice',
      }));
      await s.login('alice@test.com', 'secret');
      expect(s.state.isAuthenticated, isTrue);
      expect(s.state.isLoading, isFalse);
      expect(s.state.userProfile!.email, 'alice@test.com');
      expect(s.state.userProfile!.displayName, 'Alice');
      expect(s.state.userProfile!.userId, 'u-1');
    });

    test('given_serverError_when_login_then_setsError', () async {
      final s = _service(_apiWith(500, {}));
      await expectLater(() => s.login('a@b.com', 'pw'), throwsA(anything));
      expect(s.state.isLoading, isFalse);
      expect(s.state.error, isNotNull);
    });
  });

  group('AuthService.register', () {
    test('given_validData_when_register_then_isAuthenticated', () async {
      final s = _service(_apiWith(201, {
        'accessToken': 'at',
        'refreshToken': 'rt',
        'userId': 'u-2',
        'email': 'bob@test.com',
        'displayName': 'Bob',
      }));
      await s.register('bob@test.com', 'password', 'Bob');
      expect(s.state.isAuthenticated, isTrue);
      expect(s.state.userProfile!.displayName, 'Bob');
    });

    test('given_serverError_when_register_then_setsError', () async {
      final s = _service(_apiWith(400, {}));
      await expectLater(() => s.register('a@b.com', 'pw', 'Alice'), throwsA(anything));
      expect(s.state.error, isNotNull);
    });
  });

  group('AuthService.logout', () {
    test('given_authenticatedUser_when_logout_then_notAuthenticated', () async {
      final s = _service(_apiWith(200, {
        'accessToken': 'at',
        'refreshToken': 'rt',
        'userId': 'u-1',
        'email': 'a@b.com',
        'displayName': 'Alice',
      }));
      await s.login('a@b.com', 'pw');
      expect(s.state.isAuthenticated, isTrue);

      // New service for logout — 401 on logout call should be tolerated (best-effort)
      final logoutApi = ApiClient(
        tokenStorage: () async => 'at',
        httpClient: MockClient((_) async => http.Response('', 401)),
      );
      final s2 = AuthService(apiClient: logoutApi, tokenStorage: s.tokenStorage);
      s2.state = s.state; // copy authenticated state
      await s2.logout();
      expect(s2.state.isAuthenticated, isFalse);
    });
  });

  group('AuthService.tryRestoreSession', () {
    test('given_noStoredToken_when_tryRestore_then_returnsFalse', () async {
      final s = _service(_apiWith(200, {}));
      final restored = await s.tryRestoreSession();
      expect(restored, isFalse);
      expect(s.state.isAuthenticated, isFalse);
    });

    test('given_storedToken_when_tryRestore_then_returnsTrue', () async {
      final fakeStorage = _FakeTokenStorage();
      await fakeStorage.saveTokens(AuthToken(
        accessToken: 'at',
        refreshToken: 'rt',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        userId: 'u-3',
      ));
      final s = AuthService(
        apiClient: _apiWith(200, {}),
        tokenStorage: fakeStorage,
      );
      final restored = await s.tryRestoreSession();
      expect(restored, isTrue);
      expect(s.state.isAuthenticated, isTrue);
      expect(s.state.userProfile!.userId, 'u-3');
    });
  });

  group('AuthService.forgotPassword / resetPassword', () {
    test('given_email_when_forgotPassword_then_completes', () async {
      final s = _service(_apiWith(200, {}));
      await expectLater(() => s.forgotPassword('a@b.com'), returnsNormally);
    });

    test('given_validData_when_resetPassword_then_completes', () async {
      final s = _service(_apiWith(200, {}));
      await expectLater(() => s.resetPassword('a@b.com', 'token123', 'newPass'), returnsNormally);
    });
  });
}
