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
  final UserSocial social;
  final List<UserCategory> categories;
  final bool mustChangePassword;

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
    this.social = const UserSocial(),
    this.categories = const [],
    this.mustChangePassword = false,
  });

  String get fullName => '$firstName $lastName'.trim();

  UserProfile copyWith({
    String? firstName,
    String? lastName,
    String? avatarUrl,
    DateTime? birthDate,
    String? bio,
    String? pendingEmail,
    UserStats? stats,
    UserSocial? social,
    List<UserCategory>? categories,
    bool? mustChangePassword,
  }) {
    return UserProfile(
      id: id,
      email: email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      birthDate: birthDate ?? this.birthDate,
      bio: bio ?? this.bio,
      pendingEmail: pendingEmail ?? this.pendingEmail,
      stats: stats ?? this.stats,
      social: social ?? this.social,
      categories: categories ?? this.categories,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] as Map<String, dynamic>?;
    return UserProfile(
      id: json['id'] as String,
      email: (json['email'] as String?) ?? '',
      firstName: (json['firstName'] as String?) ?? (profile?['firstName'] as String?) ?? '',
      lastName: (json['lastName'] as String?) ?? (profile?['lastName'] as String?) ?? '',
      avatarUrl: (json['avatarUrl'] ?? profile?['avatarUrl']) as String?,
      birthDate: _parseDate(json['birthDate'] ?? profile?['birthDate']),
      bio: (json['bio'] ?? profile?['bio']) as String?,
      pendingEmail: json['pendingEmail'] as String?,
      stats: UserStats.fromJson(json['stats'] as Map<String, dynamic>?),
      social: UserSocial.fromJson(json['social'] as Map<String, dynamic>?),
      categories: _parseCategories(json['categories']),
      mustChangePassword: json['mustChangePassword'] == true,
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

class UserCategory {
  final String id;
  final String name;

  const UserCategory({required this.id, required this.name});

  factory UserCategory.fromJson(Map<String, dynamic> json) {
    return UserCategory(
      id: (json['id'] as String).trim(),
      name: (json['name'] as String?)?.trim() ?? '',
    );
  }
}

List<UserCategory> _parseCategories(Object? value) {
  if (value is List) {
    return value
        .whereType<Map<String, dynamic>>()
        .map(UserCategory.fromJson)
        .toList(growable: false);
  }
  return const [];
}

class UserSocial {
  final int followers;
  final int following;
  final bool isFollowedByViewer;

  const UserSocial({
    this.followers = 0,
    this.following = 0,
    this.isFollowedByViewer = false,
  });

  factory UserSocial.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const UserSocial();
    return UserSocial(
      followers: (json['followers'] as num?)?.toInt() ?? 0,
      following: (json['following'] as num?)?.toInt() ?? 0,
      isFollowedByViewer: json['isFollowedByViewer'] == true,
    );
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
