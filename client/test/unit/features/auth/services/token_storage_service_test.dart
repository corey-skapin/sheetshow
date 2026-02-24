import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sheetshow/features/auth/models/auth_token.dart';
import 'package:sheetshow/features/auth/services/token_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // In-memory store to back the mock platform channel.
  final store = <String, String?>{};

  void _setUpMockChannel() {
    store.clear();
    // flutter_secure_storage uses this method channel on all platforms.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall call) async {
        final args = call.arguments as Map;
        switch (call.method) {
          case 'write':
            store[args['key'] as String] = args['value'] as String?;
            return null;
          case 'read':
            return store[args['key'] as String];
          case 'delete':
            store.remove(args['key'] as String);
            return null;
          default:
            throw PlatformException(
                code: 'UNIMPLEMENTED', message: call.method);
        }
      },
    );
  }

  late TokenStorageService service;

  setUp(() {
    _setUpMockChannel();
    service = TokenStorageService(const FlutterSecureStorage());
  });

  group('TokenStorageService.saveTokens / loadTokens', () {
    test('given_token_when_save_then_loadReturnsToken', () async {
      final expiry = DateTime(2030, 1, 1);
      final token = AuthToken(
        accessToken: 'access123',
        refreshToken: 'refresh456',
        expiresAt: expiry,
        userId: 'user-1',
      );

      await service.saveTokens(token);
      final loaded = await service.loadTokens();

      expect(loaded, isNotNull);
      expect(loaded!.accessToken, 'access123');
      expect(loaded.refreshToken, 'refresh456');
      expect(loaded.userId, 'user-1');
    });

    test('given_noTokenSaved_when_load_then_returnsNull', () async {
      final loaded = await service.loadTokens();
      expect(loaded, isNull);
    });

    test('given_onlyAccessToken_when_load_then_returnsNull', () async {
      store['sheetshow_access_token'] = 'at';
      // No refresh token stored → should return null
      final loaded = await service.loadTokens();
      expect(loaded, isNull);
    });

    test('given_invalidExpiry_when_load_then_usesDefaultExpiry', () async {
      store['sheetshow_access_token'] = 'at';
      store['sheetshow_refresh_token'] = 'rt';
      store['sheetshow_token_expiry'] = 'not-a-date';
      store['sheetshow_user_id'] = 'u-1';

      final loaded = await service.loadTokens();
      expect(loaded, isNotNull);
      // expiresAt falls back to ~now+15min
      expect(loaded!.expiresAt.isAfter(DateTime.now()), isTrue);
    });
  });

  group('TokenStorageService.clearTokens', () {
    test('given_savedTokens_when_clear_then_loadReturnsNull', () async {
      final token = AuthToken(
        accessToken: 'at',
        refreshToken: 'rt',
        expiresAt: DateTime(2030),
        userId: 'u-1',
      );
      await service.saveTokens(token);
      await service.clearTokens();
      expect(await service.loadTokens(), isNull);
    });
  });

  group('TokenStorageService.getAccessToken', () {
    test('given_noToken_when_getAccessToken_then_returnsNull', () async {
      expect(await service.getAccessToken(), isNull);
    });

    test('given_savedToken_when_getAccessToken_then_returnsAccessToken',
        () async {
      final token = AuthToken(
        accessToken: 'my-at',
        refreshToken: 'rt',
        expiresAt: DateTime(2030),
        userId: 'u-1',
      );
      await service.saveTokens(token);
      expect(await service.getAccessToken(), 'my-at');
    });
  });
}
