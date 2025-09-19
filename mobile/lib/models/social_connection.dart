class SocialConnection {
  final String id;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final DateTime? followedAt;

  const SocialConnection({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
    this.followedAt,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory SocialConnection.fromJson(Map<String, dynamic> json) {
    return SocialConnection(
      id: json['id'] as String,
      firstName: (json['firstName'] ?? '') as String,
      lastName: (json['lastName'] ?? '') as String,
      avatarUrl: json['avatarUrl'] as String?,
      followedAt: _parseDate(json['followedAt']),
    );
  }

  static DateTime? _parseDate(Object? source) {
    if (source is String && source.isNotEmpty) {
      return DateTime.tryParse(source);
    }
    if (source is DateTime) return source;
    return null;
  }
}
