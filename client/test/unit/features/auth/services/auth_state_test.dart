import 'package:flutter_test/flutter_test.dart';
import 'package:sheetshow/features/auth/models/user_profile.dart';
import 'package:sheetshow/features/auth/services/auth_service.dart';

void main() {
  group('AuthState', () {
    test('given_noProfile_when_created_then_notAuthenticated', () {
      const state = AuthState();
      expect(state.isAuthenticated, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.userProfile, isNull);
    });

    test('given_profile_when_created_then_isAuthenticated', () {
      const profile = UserProfile(userId: 'u-1', email: 'a@b.com', displayName: 'Alice');
      const state = AuthState(userProfile: profile);
      expect(state.isAuthenticated, isTrue);
    });

    test('given_state_when_copyWithIsLoading_then_updatesLoading', () {
      const state = AuthState();
      final loading = state.copyWith(isLoading: true);
      expect(loading.isLoading, isTrue);
      expect(loading.userProfile, isNull);
      expect(loading.error, isNull);
    });

    test('given_state_when_copyWithError_then_setsError', () {
      const state = AuthState();
      final withError = state.copyWith(error: 'Bad credentials');
      expect(withError.error, 'Bad credentials');
      expect(withError.isLoading, isFalse);
    });

    test('given_state_when_copyWithProfile_then_setsProfile', () {
      const state = AuthState();
      const profile = UserProfile(userId: 'u-2', email: 'b@c.com', displayName: 'Bob');
      final withProfile = state.copyWith(userProfile: profile, isLoading: false);
      expect(withProfile.isAuthenticated, isTrue);
      expect(withProfile.userProfile!.userId, 'u-2');
    });

    test('given_stateWithError_when_copyWithNullError_then_clearsError', () {
      const state = AuthState(error: 'old error');
      // copyWith with no error param uses null (not the existing value)
      final cleared = state.copyWith(isLoading: false);
      expect(cleared.error, isNull);
    });

    test('given_stateWithProfile_when_copyWithNoArgs_then_preservesProfile', () {
      const profile = UserProfile(userId: 'u-3', email: 'c@d.com', displayName: 'Carol');
      const state = AuthState(userProfile: profile, isLoading: false);
      final copy = state.copyWith();
      expect(copy.userProfile, profile);
      expect(copy.isLoading, isFalse);
    });

    test('given_loadingState_when_copyWithIsLoadingFalse_then_notLoading', () {
      const state = AuthState(isLoading: true);
      final done = state.copyWith(isLoading: false);
      expect(done.isLoading, isFalse);
    });
  });
}
