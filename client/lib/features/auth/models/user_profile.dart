// T096: UserProfile — logged-in user information.

/// Profile of the currently authenticated user.
class UserProfile {
  const UserProfile({
    required this.userId,
    required this.email,
    required this.displayName,
  });

  final String userId;
  final String email;
  final String displayName;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        userId: json['userId'] as String? ?? json['id'] as String? ?? '',
        email: json['email'] as String? ?? '',
        displayName: json['displayName'] as String? ?? '',
      );
}
