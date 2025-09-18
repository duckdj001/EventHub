class UserProfile {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final DateTime? birthDate;
  final String? bio;
  final String? pendingEmail;
  final UserStats stats;

  const UserProfile({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
    this.birthDate,
    this.bio,
    this.pendingEmail,
    this.stats = const UserStats(),
  });

  String get fullName => '$firstName $lastName'.trim();

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] as Map<String, dynamic>?;
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      firstName: (json['firstName'] ?? profile?['firstName'] ?? '') as String,
      lastName: (json['lastName'] ?? profile?['lastName'] ?? '') as String,
      avatarUrl: (json['avatarUrl'] ?? profile?['avatarUrl']) as String?,
      birthDate: _parseDate(json['birthDate'] ?? profile?['birthDate']),
      bio: (json['bio'] ?? profile?['bio']) as String?,
      pendingEmail: json['pendingEmail'] as String?,
      stats: UserStats.fromJson(json['stats'] as Map<String, dynamic>?),
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    if (value is DateTime) return value;
    return null;
  }
}

class UserStats {
  final double ratingAvg;
  final int ratingCount;
  final Map<int, int> ratingDistribution;
  final int eventsUpcoming;
  final int eventsPast;
  final double participantRatingAvg;
  final int participantRatingCount;

  const UserStats({
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.ratingDistribution = const {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
    this.eventsUpcoming = 0,
    this.eventsPast = 0,
    this.participantRatingAvg = 0,
    this.participantRatingCount = 0,
  });

  factory UserStats.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const UserStats();
    }
    final distribution = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    final raw = json['ratingDistribution'];
    if (raw is Map) {
      raw.forEach((key, value) {
        final k = int.tryParse('$key');
        if (k != null && distribution.containsKey(k)) {
          distribution[k] = (value as num).toInt();
        }
      });
    }

    return UserStats(
      ratingAvg: (json['ratingAvg'] as num?)?.toDouble() ?? 0,
      ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
      ratingDistribution: distribution,
      eventsUpcoming: (json['eventsUpcoming'] as num?)?.toInt() ?? 0,
      eventsPast: (json['eventsPast'] as num?)?.toInt() ?? 0,
      participantRatingAvg: (json['participantRatingAvg'] as num?)?.toDouble() ?? 0,
      participantRatingCount: (json['participantRatingCount'] as num?)?.toInt() ?? 0,
    );
  }
}
