import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StreakService {
  // Private constructor
  StreakService._internal(this._prefs);
  static const String _entryDatesKey = 'entry_dates';
  final SharedPreferences _prefs;
  final DateFormat _dateFormat = DateFormat('dd-MM-yyyy');

  // Singleton instance
  static StreakService? _instance;
  static SharedPreferences? _prefsInstance;

  /// Initialize SharedPreferences - call this in main() before using getInstance
  static Future<void> init() async {
    _prefsInstance = await SharedPreferences.getInstance();
  }

  /// Synchronous getter for the singleton instance
  static StreakService get instance {
    if (_prefsInstance == null) {
      throw StateError('StreakService not initialized. Call StreakService.init() first.');
    }

    _instance ??= StreakService._internal(_prefsInstance!);
    return _instance!;
  }

  /// Record today's entry
  Future<bool> recordEntry() async {
    final today = DateTime.now();
    final todayFormatted = _dateFormat.format(today);

    final dates = _getStoredDates();

    // Only add today's date if it's not already recorded
    if (!dates.contains(todayFormatted)) {
      dates.add(todayFormatted);
      await _prefs.setStringList(_entryDatesKey, dates);

      return true;
    }

    return false;
  }

  /// Get all stored entry dates
  List<String> _getStoredDates() {
    return _prefs.getStringList(_entryDatesKey) ?? [];
  }

  /// Calculate current streak
  int getCurrentStreak() {
    final dates = _getStoredDates();
    if (dates.isEmpty) return 0;

    // Convert strings to DateTime objects and sort them
    final dateTimes = dates.map(_dateFormat.parse).toList()..sort((a, b) => b.compareTo(a)); // Sort in descending order

    // Check if the most recent entry is today or yesterday
    final mostRecent = dateTimes.first;

    if (!_isToday(mostRecent) && !_isYesterday(mostRecent)) {
      return 0; // Streak broken if most recent entry is older than yesterday
    }

    var streak = 1; // Start with 1 for the most recent day
    var expectedDate = mostRecent.subtract(const Duration(days: 1));

    // Count consecutive days
    for (var i = 1; i < dateTimes.length; i++) {
      if (_isSameDay(dateTimes[i], expectedDate)) {
        streak++;
        expectedDate = expectedDate.subtract(const Duration(days: 1));
      } else {
        break; // Streak broken
      }
    }

    return streak;
  }

  /// Get longest streak
  int getLongestStreak() {
    final dates = _getStoredDates();
    if (dates.isEmpty) return 0;

    // Convert strings to DateTime objects and sort them
    final dateTimes = dates.map(_dateFormat.parse).toList()..sort((a, b) => a.compareTo(b));

    var currentStreak = 1;
    var longestStreak = 1;

    for (var i = 1; i < dateTimes.length; i++) {
      final difference = dateTimes[i].difference(dateTimes[i - 1]).inDays;

      if (difference == 1) {
        currentStreak++;
        longestStreak = currentStreak > longestStreak ? currentStreak : longestStreak;
      } else {
        currentStreak = 1;
      }
    }

    return longestStreak;
  }

  /// Clear all stored dates
  Future<void> clearData() async {
    await _prefs.remove(_entryDatesKey);
  }

  /// Helper methods for date comparisons
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return _isSameDay(date, now);
  }

  bool _isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return _isSameDay(date, yesterday);
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
  }
}
