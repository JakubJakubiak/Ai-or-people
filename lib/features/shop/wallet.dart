import 'package:flutter/foundation.dart';
import 'package:humanai/features/shop/shop_items.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the player owns from the shop. Kept on the device: there is no
/// backend, so the stores are the only other record of the purchases.
class Wallet extends ChangeNotifier {
  Wallet(this._prefs);

  static const _noAdsKey = 'shopNoAds';
  static const _premiumKey = 'shopPremium';
  static const _revivesKey = 'shopRevives';
  static const _creditedKey = 'shopCreditedPurchases';

  /// How many purchase ids are remembered to avoid paying out twice.
  static const _creditedLimit = 100;

  /// Premium doubles the points of every correct answer.
  static const premiumPointsMultiplier = 2;

  static Wallet? _instance;
  static Wallet get instance => _instance!;

  static Future<void> init() async {
    _instance ??= Wallet(await SharedPreferences.getInstance());
  }

  final SharedPreferences _prefs;

  /// "Remove ads" was bought.
  bool get noAds => _prefs.getBool(_noAdsKey) ?? false;

  /// The Premium subscription is active, as last seen in the store.
  bool get premium => _prefs.getBool(_premiumKey) ?? false;

  /// No banner ads: either bought outright or part of Premium.
  bool get adFree => noAds || premium;

  int get revives => _prefs.getInt(_revivesKey) ?? 0;

  /// Gives the player what [item] contains. The same purchase can reach the
  /// app more than once (restore, unfinished purchase after a restart), so a
  /// known [purchaseId] is ignored. Returns whether anything was added.
  Future<bool> credit(ShopItem item, {String? purchaseId}) async {
    if (item.subscription) {
      final changed = !premium;
      await setPremium(active: true);
      return changed;
    }

    final credited = _prefs.getStringList(_creditedKey) ?? <String>[];
    if (purchaseId != null && purchaseId.isNotEmpty) {
      if (credited.contains(purchaseId)) return false;
      credited.add(purchaseId);
      if (credited.length > _creditedLimit) credited.removeRange(0, credited.length - _creditedLimit);
      await _prefs.setStringList(_creditedKey, credited);
    }

    if (item.consumable) {
      await _prefs.setInt(_revivesKey, revives + item.revives);
    } else {
      if (noAds) return false;
      await _prefs.setBool(_noAdsKey, true);
    }
    notifyListeners();
    return true;
  }

  /// Records whether the store still reports an active subscription.
  Future<void> setPremium({required bool active}) async {
    if (premium == active) return;
    await _prefs.setBool(_premiumKey, active);
    notifyListeners();
  }

  /// Uses up one revive. Returns false if the player has none.
  Future<bool> useRevive() async {
    if (revives <= 0) return false;
    await _prefs.setInt(_revivesKey, revives - 1);
    notifyListeners();
    return true;
  }
}
