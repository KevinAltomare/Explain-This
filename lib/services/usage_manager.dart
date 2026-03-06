import 'package:shared_preferences/shared_preferences.dart';

class UsageManager {
  static const String _countKey = 'explanationsUsed';
  static const String _startKey = 'usageStartDate';
  static const int freeLimit = 3;
  static const int windowDays = 30;

  static Future<bool> canUseExplanation({required bool isPremium}) async {
    if (isPremium) return true;

    final prefs = await SharedPreferences.getInstance();

    final now = DateTime.now();
    final startMillis = prefs.getInt(_startKey);
    final count = prefs.getInt(_countKey) ?? 0;

    if (startMillis == null) {
      await prefs.setInt(_startKey, now.millisecondsSinceEpoch);
      await prefs.setInt(_countKey, 0);
      return true;
    }

    final startDate = DateTime.fromMillisecondsSinceEpoch(startMillis);
    final daysPassed = now.difference(startDate).inDays;

    if (daysPassed >= windowDays) {
      await prefs.setInt(_startKey, now.millisecondsSinceEpoch);
      await prefs.setInt(_countKey, 0);
      return true;
    }

    return count < freeLimit;
  }

  static Future<void> incrementUsage() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_countKey) ?? 0;
    await prefs.setInt(_countKey, count + 1);
  }
}