class EventStoryAuthor {
  final String id;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;

  const EventStoryAuthor({
    required this.id,
    this.firstName,
    this.lastName,
    this.avatarUrl,
  });

  String get fullName {
    final parts = [firstName, lastName]
        .where((part) => part != null && part!.trim().isNotEmpty)
        .map((part) => part!.trim());
    final joined = parts.join(' ');
    return joined.isNotEmpty ? joined : 'Участник';
  }

  factory EventStoryAuthor.fromJson(Map<String, dynamic> json) {
    return EventStoryAuthor(
      id: json['id'] as String,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}

class EventStory {
  final String id;
  final String url;
  final DateTime createdAt;
  final EventStoryAuthor? author;

  const EventStory({
    required this.id,
    required this.url,
    required this.createdAt,
    this.author,
  });

  factory EventStory.fromJson(Map<String, dynamic> json) {
    return EventStory(
      id: json['id'] as String,
      url: json['url'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      author: json['author'] is Map<String, dynamic>
          ? EventStoryAuthor.fromJson(json['author'] as Map<String, dynamic>)
          : null,
    );
  }
}
