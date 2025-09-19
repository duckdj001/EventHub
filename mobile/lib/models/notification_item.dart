class AppNotification {
  final String id;
  final NotificationType type;
  final String message;
  final bool read;
  final DateTime createdAt;
  final NotificationEvent? event;

  const AppNotification({
    required this.id,
    required this.type,
    required this.message,
    required this.read,
    required this.createdAt,
    this.event,
  });

  bool get isUnread => !read;

  AppNotification copyWith({bool? read}) {
    return AppNotification(
      id: id,
      type: type,
      message: message,
      read: read ?? this.read,
      createdAt: createdAt,
      event: event,
    );
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      type: _parseType(json['type'] as String?),
      message: (json['message'] ?? '') as String,
      read: json['read'] == true,
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
      event: json['event'] != null ? NotificationEvent.fromJson(json['event'] as Map<String, dynamic>) : null,
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value)?.toLocal();
    }
    if (value is DateTime) return value;
    return null;
  }
}

enum NotificationType { newEvent, eventReminder, unknown }

NotificationType _parseType(String? raw) {
  switch (raw) {
    case 'NEW_EVENT':
      return NotificationType.newEvent;
    case 'EVENT_REMINDER':
      return NotificationType.eventReminder;
    default:
      return NotificationType.unknown;
  }
}

class NotificationEvent {
  final String id;
  final String title;
  final DateTime? startAt;
  final String? coverUrl;
  final NotificationUser? owner;

  const NotificationEvent({
    required this.id,
    required this.title,
    this.startAt,
    this.coverUrl,
    this.owner,
  });

  String get ownerName => owner?.fullName ?? '';

  factory NotificationEvent.fromJson(Map<String, dynamic> json) {
    return NotificationEvent(
      id: json['id'] as String,
      title: (json['title'] ?? '') as String,
      startAt: AppNotification._parseDate(json['startAt']),
      coverUrl: json['coverUrl'] as String?,
      owner: json['owner'] != null ? NotificationUser.fromJson(json['owner'] as Map<String, dynamic>) : null,
    );
  }
}

class NotificationUser {
  final String id;
  final String firstName;
  final String lastName;
  final String? avatarUrl;

  const NotificationUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory NotificationUser.fromJson(Map<String, dynamic> json) {
    return NotificationUser(
      id: json['id'] as String,
      firstName: (json['firstName'] ?? '') as String,
      lastName: (json['lastName'] ?? '') as String,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}
