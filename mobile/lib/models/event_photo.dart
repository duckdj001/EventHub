class EventPhotoAuthor {
  final String id;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;

  const EventPhotoAuthor({
    required this.id,
    this.firstName,
    this.lastName,
    this.avatarUrl,
  });

  String get fullName {
    final parts = [firstName, lastName]
        .where((p) => p != null && p!.trim().isNotEmpty)
        .map((p) => p!.trim());
    final name = parts.join(' ');
    return name.isNotEmpty ? name : 'Участник';
  }

  factory EventPhotoAuthor.fromJson(Map<String, dynamic> json) {
    return EventPhotoAuthor(
      id: json['id'] as String,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}

class EventPhoto {
  final String id;
  final String url;
  final DateTime createdAt;
  final EventPhotoAuthor? author;

  const EventPhoto({
    required this.id,
    required this.url,
    required this.createdAt,
    this.author,
  });

  factory EventPhoto.fromJson(Map<String, dynamic> json) {
    return EventPhoto(
      id: json['id'] as String,
      url: json['url'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      author: json['author'] is Map<String, dynamic>
          ? EventPhotoAuthor.fromJson(json['author'] as Map<String, dynamic>)
          : null,
    );
  }
}
