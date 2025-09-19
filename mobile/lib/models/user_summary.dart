class UserSummary {
  final String id;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final String? email;

  const UserSummary({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
    this.email,
  });

  String get fullName {
    final name = '$firstName $lastName'.trim();
    if (name.isNotEmpty) return name;
    return email ?? 'Пользователь';
  }

  factory UserSummary.fromJson(Map<String, dynamic> json) {
    return UserSummary(
      id: json['id'] as String,
      firstName: (json['firstName'] ?? '') as String,
      lastName: (json['lastName'] ?? '') as String,
      avatarUrl: json['avatarUrl'] as String?,
      email: json['email'] as String?,
    );
  }
}
