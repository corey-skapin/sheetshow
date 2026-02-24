// T095: AuthToken — access/refresh token pair with expiry.

/// JWT token pair returned by the authentication API.
class AuthToken {
  const AuthToken({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.userId,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String userId;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'expiresAt': expiresAt.toIso8601String(),
        'userId': userId,
      };

  factory AuthToken.fromJson(Map<String, dynamic> json) => AuthToken(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
        expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? '') ??
            DateTime.now().add(const Duration(minutes: 15)),
        userId: json['userId'] as String? ?? '',
      );
}
