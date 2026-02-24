import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sheetshow/features/auth/models/auth_token.dart';

// T097: TokenStorageService — uses flutter_secure_storage (Windows Credential Manager).

const _kAccessTokenKey = 'sheetshow_access_token';
const _kRefreshTokenKey = 'sheetshow_refresh_token';
const _kTokenExpiryKey = 'sheetshow_token_expiry';
const _kUserIdKey = 'sheetshow_user_id';

/// Securely stores and retrieves JWT tokens using the platform credential store.
class TokenStorageService {
  TokenStorageService(this._storage);

  final FlutterSecureStorage _storage;

  /// Persist the [AuthToken] to secure storage.
  Future<void> saveTokens(AuthToken token) async {
    await Future.wait([
      _storage.write(key: _kAccessTokenKey, value: token.accessToken),
      _storage.write(key: _kRefreshTokenKey, value: token.refreshToken),
      _storage.write(
          key: _kTokenExpiryKey, value: token.expiresAt.toIso8601String()),
      _storage.write(key: _kUserIdKey, value: token.userId),
    ]);
  }

  /// Load the stored [AuthToken], or null if no token is stored.
  Future<AuthToken?> loadTokens() async {
    final results = await Future.wait([
      _storage.read(key: _kAccessTokenKey),
      _storage.read(key: _kRefreshTokenKey),
      _storage.read(key: _kTokenExpiryKey),
      _storage.read(key: _kUserIdKey),
    ]);

    final accessToken = results[0];
    final refreshToken = results[1];
    final expiryStr = results[2];
    final userId = results[3];

    if (accessToken == null || refreshToken == null) return null;

    return AuthToken(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: DateTime.tryParse(expiryStr ?? '') ??
          DateTime.now().add(const Duration(minutes: 15)),
      userId: userId ?? '',
    );
  }

  /// Clear all stored tokens (logout).
  Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: _kAccessTokenKey),
      _storage.delete(key: _kRefreshTokenKey),
      _storage.delete(key: _kTokenExpiryKey),
      _storage.delete(key: _kUserIdKey),
    ]);
  }

  /// Read just the access token string.
  Future<String?> getAccessToken() async {
    return _storage.read(key: _kAccessTokenKey);
  }
}

/// Riverpod provider for [TokenStorageService].
final tokenStorageServiceProvider = Provider<TokenStorageService>((ref) {
  const storage = FlutterSecureStorage(
    wOptions: WindowsOptions(useBackwardCompatibility: false),
  );
  return TokenStorageService(storage);
});
