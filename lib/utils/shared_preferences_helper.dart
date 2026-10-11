import 'package:humanai/models/game_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesHelper {
  static SharedPreferences? _prefs;
  static const String _bestScoreKey = 'bestScore';
  static const String _enabledTypesKey = 'enabledTypes';
  static const String _howToPlaySeenKey = 'howToPlaySeen';

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

  /// Which kinds of content the player wants to see (all of them by default).
  static Set<MediaType> getEnabledTypes() {
    final names = _prefs?.getStringList(_enabledTypesKey);
    final types = MediaType.values.where((t) => names?.contains(t.name) ?? true).toSet();
    return types.isEmpty ? MediaType.values.toSet() : types;
  }

  static Future<void> setEnabledTypes(Set<MediaType> types) async {
    await _prefs?.setStringList(_enabledTypesKey, types.map((t) => t.name).toList());
  }

  static bool getHowToPlaySeen() => _prefs?.getBool(_howToPlaySeenKey) ?? false;

  static Future<void> setHowToPlaySeen() async {
    await _prefs?.setBool(_howToPlaySeenKey, true);
  }
}
