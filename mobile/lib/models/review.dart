import 'package:characters/characters.dart';

class ReviewAuthor {
  final String id;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;
  final String? email;

  const ReviewAuthor({
    required this.id,
    this.firstName,
    this.lastName,
    this.avatarUrl,
    this.email,
  });

  String get initials {
    final parts = [firstName, lastName]
        .where((p) => p != null && p!.trim().isNotEmpty)
        .map((p) => p!.trim());
    final combined = parts.join(' ');
    if (combined.isNotEmpty) {
      return combined.characters.first.toUpperCase();
    }
    if (email != null && email!.isNotEmpty) {
      return email!.characters.first.toUpperCase();
    }
    return 'U';
  }

  String get fullName {
    final parts = [firstName, lastName]
        .where((p) => p != null && p!.trim().isNotEmpty)
        .map((p) => p!.trim());
    final name = parts.join(' ');
    return name.isNotEmpty ? name : (email ?? 'Пользователь');
  }

  factory ReviewAuthor.fromJson(Map<String, dynamic> json) {
    return ReviewAuthor(
      id: json['id'] as String,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      email: json['email'] as String?,
    );
  }
}

class ReviewEventInfo {
  final String id;
  final String title;
  final DateTime startAt;
  final DateTime endAt;

  const ReviewEventInfo({
    required this.id,
    required this.title,
    required this.startAt,
    required this.endAt,
  });

  factory ReviewEventInfo.fromJson(Map<String, dynamic> json) {
    return ReviewEventInfo(
      id: json['id'] as String,
      title: (json['title'] ?? '') as String,
      startAt: DateTime.parse(json['startAt'] as String),
      endAt: DateTime.parse(json['endAt'] as String),
    );
  }
}

class Review {
  final String id;
  final int rating;
  final String? text;
  final DateTime createdAt;
  final ReviewAuthor author;
  final ReviewEventInfo? event;

  const Review({
    required this.id,
    required this.rating,
    this.text,
    required this.createdAt,
    required this.author,
    this.event,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] as String,
      rating: (json['rating'] as num).toInt(),
      text: json['text'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      author: ReviewAuthor.fromJson(json['author'] as Map<String, dynamic>),
      event: json['event'] is Map<String, dynamic>
          ? ReviewEventInfo.fromJson(json['event'] as Map<String, dynamic>)
          : null,
    );
  }
}
