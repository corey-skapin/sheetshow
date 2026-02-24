import 'package:flutter_test/flutter_test.dart';
import 'package:sheetshow/features/auth/models/auth_token.dart';

void main() {
  final futureTime = DateTime(2099, 12, 31, 23, 59, 59);
  final pastTime = DateTime(2000, 1, 1);

  group('AuthToken', () {
    test('constructs with required fields', () {
      final token = AuthToken(
        accessToken: 'access123',
        refreshToken: 'refresh456',
        expiresAt: futureTime,
        userId: 'user-1',
      );
      expect(token.accessToken, 'access123');
      expect(token.refreshToken, 'refresh456');
      expect(token.expiresAt, futureTime);
      expect(token.userId, 'user-1');
    });

    group('isExpired', () {
      test('returns false when expiry is in the future', () {
        final token = AuthToken(
          accessToken: 'a',
          refreshToken: 'r',
          expiresAt: futureTime,
          userId: 'u',
        );
        expect(token.isExpired, isFalse);
      });

      test('returns true when expiry is in the past', () {
        final token = AuthToken(
          accessToken: 'a',
          refreshToken: 'r',
          expiresAt: pastTime,
          userId: 'u',
        );
        expect(token.isExpired, isTrue);
      });
    });

    group('toJson', () {
      test('serializes all fields', () {
        final token = AuthToken(
          accessToken: 'access123',
          refreshToken: 'refresh456',
          expiresAt: futureTime,
          userId: 'user-1',
        );
        final json = token.toJson();
        expect(json['accessToken'], 'access123');
        expect(json['refreshToken'], 'refresh456');
        expect(json['expiresAt'], futureTime.toIso8601String());
        expect(json['userId'], 'user-1');
      });
    });

    group('fromJson', () {
      test('deserializes valid JSON', () {
        final json = {
          'accessToken': 'access-abc',
          'refreshToken': 'refresh-def',
          'expiresAt': futureTime.toIso8601String(),
          'userId': 'user-99',
        };
        final token = AuthToken.fromJson(json);
        expect(token.accessToken, 'access-abc');
        expect(token.refreshToken, 'refresh-def');
        expect(token.userId, 'user-99');
        expect(token.expiresAt, futureTime);
      });

      test('falls back to 15-min expiry on invalid date string', () {
        final json = {
          'accessToken': 'a',
          'refreshToken': 'r',
          'expiresAt': 'not-a-date',
          'userId': 'u',
        };
        final before = DateTime.now();
        final token = AuthToken.fromJson(json);
        final after = DateTime.now();
        expect(
          token.expiresAt.isAfter(before.add(const Duration(minutes: 14))),
          isTrue,
        );
        expect(
          token.expiresAt.isBefore(after.add(const Duration(minutes: 16))),
          isTrue,
        );
      });

      test('handles missing userId with empty string', () {
        final json = {
          'accessToken': 'a',
          'refreshToken': 'r',
          'expiresAt': futureTime.toIso8601String(),
        };
        final token = AuthToken.fromJson(json);
        expect(token.userId, '');
      });

      test('round-trips through toJson and fromJson', () {
        final original = AuthToken(
          accessToken: 'access-xyz',
          refreshToken: 'refresh-xyz',
          expiresAt: futureTime,
          userId: 'user-42',
        );
        final copy = AuthToken.fromJson(original.toJson());
        expect(copy.accessToken, original.accessToken);
        expect(copy.refreshToken, original.refreshToken);
        expect(copy.userId, original.userId);
        expect(copy.expiresAt, original.expiresAt);
      });
    });
  });
}
