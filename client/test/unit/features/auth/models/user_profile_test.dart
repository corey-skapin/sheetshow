import 'package:flutter_test/flutter_test.dart';
import 'package:sheetshow/features/auth/models/user_profile.dart';

void main() {
  group('UserProfile', () {
    test('constructs with required fields', () {
      const profile = UserProfile(
        userId: 'user-1',
        email: 'user@example.com',
        displayName: 'Alice',
      );
      expect(profile.userId, 'user-1');
      expect(profile.email, 'user@example.com');
      expect(profile.displayName, 'Alice');
    });

    group('fromJson', () {
      test('deserializes userId field', () {
        final json = {
          'userId': 'user-abc',
          'email': 'a@b.com',
          'displayName': 'Bob',
        };
        final profile = UserProfile.fromJson(json);
        expect(profile.userId, 'user-abc');
        expect(profile.email, 'a@b.com');
        expect(profile.displayName, 'Bob');
      });

      test('falls back to id field when userId is absent', () {
        final json = {
          'id': 'user-fallback',
          'email': 'c@d.com',
          'displayName': 'Carol',
        };
        final profile = UserProfile.fromJson(json);
        expect(profile.userId, 'user-fallback');
      });

      test('defaults to empty strings when fields are absent', () {
        const json = <String, dynamic>{};
        final profile = UserProfile.fromJson(json);
        expect(profile.userId, '');
        expect(profile.email, '');
        expect(profile.displayName, '');
      });

      test('handles null values for string fields', () {
        final json = <String, dynamic>{
          'userId': null,
          'email': null,
          'displayName': null,
        };
        final profile = UserProfile.fromJson(json);
        expect(profile.userId, '');
        expect(profile.email, '');
        expect(profile.displayName, '');
      });
    });
  });
}
