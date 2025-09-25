class NotificationPreferences {
  final bool newEvent;
  final bool eventReminder;
  final bool participationApproved;
  final bool newFollower;
  final bool organizerContent;
  final bool followedStory;
  final bool eventUpdated;

  const NotificationPreferences({
    required this.newEvent,
    required this.eventReminder,
    required this.participationApproved,
    required this.newFollower,
    required this.organizerContent,
    required this.followedStory,
    required this.eventUpdated,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    bool parseBool(String key, bool fallback) {
      final value = json[key];
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final lower = value.toLowerCase();
        if (lower == 'true' || lower == '1') return true;
        if (lower == 'false' || lower == '0') return false;
      }
      return fallback;
    }

    return NotificationPreferences(
      newEvent: parseBool('newEvent', true),
      eventReminder: parseBool('eventReminder', true),
      participationApproved: parseBool('participationApproved', true),
      newFollower: parseBool('newFollower', true),
      organizerContent: parseBool('organizerContent', true),
      followedStory: parseBool('followedStory', true),
      eventUpdated: parseBool('eventUpdated', true),
    );
  }

  NotificationPreferences copyWith({
    bool? newEvent,
    bool? eventReminder,
    bool? participationApproved,
    bool? newFollower,
    bool? organizerContent,
    bool? followedStory,
    bool? eventUpdated,
  }) {
    return NotificationPreferences(
      newEvent: newEvent ?? this.newEvent,
      eventReminder: eventReminder ?? this.eventReminder,
      participationApproved:
          participationApproved ?? this.participationApproved,
      newFollower: newFollower ?? this.newFollower,
      organizerContent: organizerContent ?? this.organizerContent,
      followedStory: followedStory ?? this.followedStory,
      eventUpdated: eventUpdated ?? this.eventUpdated,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'newEvent': newEvent,
      'eventReminder': eventReminder,
      'participationApproved': participationApproved,
      'newFollower': newFollower,
      'organizerContent': organizerContent,
      'followedStory': followedStory,
      'eventUpdated': eventUpdated,
    };
  }
}

extension NotificationPreferencesAccess on NotificationPreferences {
  bool flag(NotificationPreferenceKey key) {
    switch (key) {
      case NotificationPreferenceKey.newEvent:
        return newEvent;
      case NotificationPreferenceKey.eventReminder:
        return eventReminder;
      case NotificationPreferenceKey.participationApproved:
        return participationApproved;
      case NotificationPreferenceKey.newFollower:
        return newFollower;
      case NotificationPreferenceKey.organizerContent:
        return organizerContent;
      case NotificationPreferenceKey.followedStory:
        return followedStory;
      case NotificationPreferenceKey.eventUpdated:
        return eventUpdated;
    }
  }
}

enum NotificationPreferenceKey {
  newEvent,
  eventReminder,
  participationApproved,
  newFollower,
  organizerContent,
  followedStory,
  eventUpdated,
}
