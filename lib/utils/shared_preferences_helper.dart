import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesHelper {
  static SharedPreferences? _prefs;
  static const String _bestScoreKey = 'bestScore';
  // static const String _dayKey = 'selectedDay';
  // static const String _trueDayKey = 'trueDay'; 
  // static const String _dayUsedDateKey = 'dayUsedDate';

  // Initialize SharedPreferences instance
  static Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Save the best score
  static Future<bool> setBestScore(int score) async {
    if (_prefs != null) {
      return _prefs!.setInt(_bestScoreKey, score);
    }
    return false;
  }

  // Retrieve the best score
  static int getBestScore() {
    return _prefs?.getInt(_bestScoreKey) ?? 0;
  }

  // Save the selected day
  // static Future<bool> setDay(int day) async {
  //   if (_prefs != null) {
  //     return _prefs!.setInt(_dayKey, day);
  //   }
  //   return false;
  // }

  // Retrieve the selected day
  // static int getDay() {
  //   return _prefs?.getInt(_dayKey) ?? 1;
  // }

  // Save the trueDay boolean flag
  // static Future<bool> setTrueDay(bool value) async {
  //   if (_prefs != null) {
  //     return _prefs!.setBool(_trueDayKey, value);
  //   }
  //   return false;
  // }

  // Retrieve the trueDay boolean flag
  // static bool getTrueDay() {
  //   return _prefs?.getBool(_trueDayKey) ?? false; // Defaults to false if not set
  // }

  // Save the date when the function was last used
  // static Future<bool> setDayUsedDate(String date) async {
  //   if (_prefs != null) {
  //     return _prefs!.setString(_dayUsedDateKey, date);
  //   }
  //   return false;
  // }

// Retrieve the date when the function was last used
  // static String getDayUsedDate() {
  //   return _prefs?.getString(_dayUsedDateKey) ?? '';
  // }
}
