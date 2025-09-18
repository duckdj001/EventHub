class ParticipationUser {
  final String id;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;
  final String? email;

  const ParticipationUser({
    required this.id,
    this.firstName,
    this.lastName,
    this.avatarUrl,
    this.email,
  });

  String get fullName {
    final parts = [firstName, lastName].where((p) => p != null && p!.trim().isNotEmpty).map((p) => p!.trim());
    final joined = parts.join(' ');
    if (joined.isNotEmpty) return joined;
    return email ?? 'Участник';
  }

  factory ParticipationUser.fromJson(Map<String, dynamic> json) {
    return ParticipationUser(
      id: json['id'] as String,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      email: json['email'] as String?,
    );
  }
}

class Participation {
  final String id;
  final String eventId;
  final String userId;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final ParticipationUser? user;
  final ParticipantReview? participantReview;

  const Participation({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.user,
    this.participantReview,
  });

  Participation copyWith({String? status, DateTime? updatedAt, ParticipantReview? participantReview}) {
    return Participation(
      id: id,
      eventId: eventId,
      userId: userId,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      user: user,
      participantReview: participantReview ?? this.participantReview,
    );
  }

  factory Participation.fromJson(Map<String, dynamic> json) {
    final createdStr = (json['createdAt'] as String?) ?? (json['updatedAt'] as String?);
    if (createdStr == null || createdStr.isEmpty) {
      throw ArgumentError('Participation JSON is missing createdAt/updatedAt');
    }
    final updatedStr = json['updatedAt'] as String?;
    ParticipantReview? review;
    final reviewJson = json['participantReview'];
    if (reviewJson is Map<String, dynamic>) {
      final id = reviewJson['id'];
      if (id is String && id.isNotEmpty) {
        review = ParticipantReview.fromJson(reviewJson);
      }
    }
    return Participation(
      id: json['id'] as String,
      eventId: json['eventId'] as String,
      userId: json['userId'] as String,
      status: (json['status'] as String).toLowerCase(),
      createdAt: DateTime.parse(createdStr),
      updatedAt: updatedStr != null && updatedStr.isNotEmpty ? DateTime.parse(updatedStr) : null,
      user: json['user'] is Map<String, dynamic>
          ? ParticipationUser.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      participantReview: review,
    );
  }
}

class ParticipantReview {
  final String id;
  final int rating;
  final String? text;
  final DateTime createdAt;

  const ParticipantReview({required this.id, required this.rating, this.text, required this.createdAt});

  factory ParticipantReview.fromJson(Map<String, dynamic> json) {
    return ParticipantReview(
      id: (json['id'] ?? '') as String,
      rating: (json['rating'] as num).toInt(),
      text: json['text'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class ParticipationRequestResult {
  final Participation participation;
  final bool autoconfirmed;

  ParticipationRequestResult({required this.participation, required this.autoconfirmed});
}
