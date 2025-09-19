import 'package:shared_preferences/shared_preferences.dart';

class ReviewPromptStorage {
  static const _dismissPrefix = 'review_prompt_dismissed_';
  static const _reviewedPrefix = 'review_prompt_reviewed_';
  static const _dismissCooldownMs = 6 * 60 * 60 * 1000; // 6 часов

  static String _key(String userId, String eventId) => '${userId}_$eventId';

  static Future<void> markDismissed(String userId, String eventId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_dismissPrefix${_key(userId, eventId)}', DateTime.now().millisecondsSinceEpoch);
  }

  static Future<bool> isDismissed(String userId, String eventId) async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt('$_dismissPrefix${_key(userId, eventId)}');
    if (ts == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - ts > _dismissCooldownMs) {
      await prefs.remove('$_dismissPrefix${_key(userId, eventId)}');
      return false;
    }
    return true;
  }

  static Future<void> markReviewed(String userId, String eventId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_reviewedPrefix${_key(userId, eventId)}', true);
  }

  static Future<bool> isReviewed(String userId, String eventId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_reviewedPrefix${_key(userId, eventId)}') ?? false;
  }
}
