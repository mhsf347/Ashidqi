import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for Ibadah Journal (Mutaba'ah Yaumiyah)
/// Stores daily checklist data in SharedPreferences
class JournalService {
  static const String _prefix = 'journal_';
  static const int maxDaysHistory = 90; // Keep 90 days of history

  /// Default checklist items
  static List<Map<String, dynamic>> get defaultItems => [
        {'id': 'subuh', 'label': 'Sholat Subuh', 'icon': 'sunrise', 'done': false},
        {'id': 'dzuhur', 'label': 'Sholat Dzuhur', 'icon': 'sun', 'done': false},
        {'id': 'ashar', 'label': 'Sholat Ashar', 'icon': 'sun_low', 'done': false},
        {'id': 'maghrib', 'label': 'Sholat Maghrib', 'icon': 'sunset', 'done': false},
        {'id': 'isya', 'label': 'Sholat Isya', 'icon': 'moon', 'done': false},
        {'id': 'dhuha', 'label': 'Sholat Dhuha', 'icon': 'dhuha', 'done': false},
        {'id': 'tahajud', 'label': 'Sholat Tahajud', 'icon': 'night', 'done': false},
        {'id': 'quran', 'label': 'Baca Al-Quran', 'icon': 'quran', 'done': false},
        {'id': 'puasa', 'label': 'Puasa Sunnah', 'icon': 'fasting', 'done': false},
        {'id': 'sedekah', 'label': 'Sedekah', 'icon': 'charity', 'done': false},
        {'id': 'dzikir_pagi', 'label': 'Dzikir Pagi', 'icon': 'morning', 'done': false},
        {'id': 'dzikir_sore', 'label': 'Dzikir Sore', 'icon': 'evening', 'done': false},
      ];

  static String _dateKey(DateTime date) {
    return '$_prefix${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Load journal data for a specific date
  static Future<List<Map<String, dynamic>>> loadDay(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _dateKey(date);
    final stored = prefs.getString(key);

    if (stored != null) {
      try {
        final List<dynamic> decoded = json.decode(stored);
        return decoded.cast<Map<String, dynamic>>();
      } catch (_) {}
    }

    return defaultItems;
  }

  /// Save journal data for a specific date
  static Future<void> saveDay(
      DateTime date, List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _dateKey(date);
    await prefs.setString(key, json.encode(items));
  }

  /// Toggle a specific item's done state
  static Future<List<Map<String, dynamic>>> toggleItem(
      DateTime date, String itemId) async {
    final items = await loadDay(date);
    for (var item in items) {
      if (item['id'] == itemId) {
        item['done'] = !(item['done'] ?? false);
        break;
      }
    }
    await saveDay(date, items);
    return items;
  }

  /// Get completion percentage for a specific date (0.0 - 1.0)
  static Future<double> getCompletion(DateTime date) async {
    final items = await loadDay(date);
    if (items.isEmpty) return 0.0;
    final done = items.where((i) => i['done'] == true).length;
    return done / items.length;
  }

  /// Get completion data for last N days
  static Future<Map<DateTime, double>> getWeeklyStats(
      {int days = 7}) async {
    final result = <DateTime, double>{};
    final now = DateTime.now();

    for (int i = 0; i < days; i++) {
      final date = DateTime(now.year, now.month, now.day - i);
      result[date] = await getCompletion(date);
    }

    return result;
  }

  /// Get streak (consecutive days with at least 50% completion)
  static Future<int> getStreak() async {
    final now = DateTime.now();
    int streak = 0;

    for (int i = 0; i < maxDaysHistory; i++) {
      final date = DateTime(now.year, now.month, now.day - i);
      final completion = await getCompletion(date);
      if (completion >= 0.5) {
        streak++;
      } else {
        break;
      }
    }

    return streak;
  }
}
