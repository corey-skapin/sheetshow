import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_client.dart';
import '../models/auth_token.dart';
import '../models/user_profile.dart';
import 'token_storage_service.dart';

// T099: AuthService — register, login, logout, refresh, password flows.

/// Authentication state.
class AuthState {
  const AuthState({
    this.userProfile,
    this.isLoading = false,
    this.error,
  });

  final UserProfile? userProfile;
  final bool isLoading;
  final String? error;

  bool get isAuthenticated => userProfile != null;

  AuthState copyWith({
    UserProfile? userProfile,
    bool? isLoading,
    String? error,
  }) =>
      AuthState(
        userProfile: userProfile ?? this.userProfile,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

/// Manages authentication state and token lifecycle.
class AuthService extends StateNotifier<AuthState> {
  AuthService({
    required this.apiClient,
    required this.tokenStorage,
  }) : super(const AuthState());

  final ApiClient apiClient;
  final TokenStorageService tokenStorage;

  Future<void> register(
    String email,
    String password,
    String displayName,
  ) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final json = await apiClient.post('/auth/register', {
        'email': email,
        'password': password,
        'displayName': displayName,
      });
      await _handleTokenResponse(json);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final json =
          await apiClient.post('/auth/login', {'email': email, 'password': password});
      await _handleTokenResponse(json);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await apiClient.post('/auth/logout', null);
    } catch (_) {
      // Best-effort server-side logout
    }
    await tokenStorage.clearTokens();
    state = const AuthState();
  }

  Future<bool> tryRestoreSession() async {
    final token = await tokenStorage.loadTokens();
    if (token == null) return false;

    state = state.copyWith(
      userProfile: UserProfile(
        userId: token.userId,
        email: '',
        displayName: '',
      ),
    );
    return true;
  }

  Future<void> forgotPassword(String email) async {
    await apiClient.post('/auth/forgot-password', {'email': email});
  }

  Future<void> resetPassword(
      String email, String token, String newPassword) async {
    await apiClient.post('/auth/reset-password', {
      'email': email,
      'token': token,
      'newPassword': newPassword,
    });
  }

  Future<void> _handleTokenResponse(Map<String, dynamic> json) async {
    final token = AuthToken.fromJson({
      'accessToken': json['accessToken'],
      'refreshToken': json['refreshToken'],
      'expiresAt': DateTime.now()
          .add(const Duration(minutes: 15))
          .toIso8601String(),
      'userId': json['userId'] ?? '',
    });

    await tokenStorage.saveTokens(token);

    final profile = UserProfile(
      userId: json['userId'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
    );

    state = state.copyWith(isLoading: false, userProfile: profile);
  }
}

/// Riverpod provider for [AuthService].
final authServiceProvider =
    StateNotifierProvider<AuthService, AuthState>((ref) {
  return AuthService(
    apiClient: ref.watch(apiClientProvider),
    tokenStorage: ref.watch(tokenStorageServiceProvider),
  );
});
