import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesHelper {
  static SharedPreferences? _prefs;
  static const String _bestScoreKey = 'bestScore';

  static Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static Future<bool> setBestScore(int score) async {
    if (_prefs != null) {
      return _prefs!.setInt(_bestScoreKey, score);
    }
    return false;
  }

  static int getBestScore() {
    return _prefs?.getInt(_bestScoreKey) ?? 0; // Returns 0 if no score found
  }
}
