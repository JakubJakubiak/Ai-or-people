import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:humanai/features/shop/shop_items.dart';
import 'package:humanai/features/shop/wallet.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

/// Talks to Google Play Billing / StoreKit and hands bought items to the
/// [Wallet]. The game works without it: if the store cannot be reached the
/// shop shows its items without prices and the buttons stay off.
class StoreService extends ChangeNotifier {
  StoreService._();

  static final instance = StoreService._();

  final _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool _loading = true;
  bool _available = false;
  Map<String, ProductDetails> _products = const {};
  String? _pendingId;
  bool _restoring = false;

  /// Set while the store reports what the player currently owns; a Premium
  /// purchase seen in that window keeps the subscription on.
  bool _syncing = false;
  bool _premiumSeen = false;
  String? _notice;
  bool _noticeIsError = false;

  /// True until the first answer from the store.
  bool get loading => _loading;

  /// Whether the store could be reached and has the products.
  bool get available => _available && _products.isNotEmpty;

  ProductDetails? product(ShopItem item) => _products[item.id];

  /// Id of the item whose purchase is in progress.
  String? get pendingId => _pendingId;
  bool get restoring => _restoring;

  /// Short message for the shop screen (thanks, errors, restore result).
  String? get notice => _notice;
  bool get noticeIsError => _noticeIsError;

  Future<void> init() async {
    // Purchases finished while the app was closed arrive on this stream, so
    // it has to be listened to right at start.
    _subscription ??= _iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) => debugPrint('Purchase stream error: $e'),
    );
    try {
      _available = await _iap.isAvailable();
      if (_available) {
        final response = await _iap.queryProductDetails(ShopItem.ids);
        if (response.notFoundIDs.isNotEmpty) debugPrint('Products not in the store yet: ${response.notFoundIDs}');
        _products = {for (final p in response.productDetails) p.id: p};
        // Checks whether Premium is still active, brings "Remove ads" back
        // after a reinstall and pays out revive packs whose purchase was
        // interrupted. Both stores answer this without asking for a password
        // (StoreKit 2 reads the current entitlements).
        await _syncOwned();
      }
    } catch (e) {
      debugPrint('Store not available: $e');
      _available = false;
    }
    _loading = false;
    notifyListeners();
  }

  /// Starts buying [item]. The result comes back through the purchase stream.
  Future<void> buy(ShopItem item) async {
    final details = _products[item.id];
    if (details == null || _pendingId != null) return;
    _pendingId = item.id;
    _notice = null;
    notifyListeners();
    final param = PurchaseParam(productDetails: details);
    try {
      final started = item.consumable ? await _iap.buyConsumable(purchaseParam: param) : await _iap.buyNonConsumable(purchaseParam: param);
      if (!started) _finish(notice: 'The purchase could not be started. Try again.', error: true);
    } catch (e) {
      debugPrint('Purchase failed to start: $e');
      _finish(notice: 'The purchase could not be started. Try again.', error: true);
    }
  }

  Future<void> restore() async {
    if (_restoring) return;
    _restoring = true;
    _notice = 'Restoring purchases…';
    _noticeIsError = false;
    notifyListeners();
    final wallet = Wallet.instance;
    if (await _syncOwned()) {
      _notice = switch ((wallet.premium, wallet.noAds)) {
        (true, _) => 'Premium is active.',
        (false, true) => 'Remove ads is active.',
        _ => 'Nothing to restore for this account.',
      };
    } else {
      _notice = 'Restoring failed. Check your connection and try again.';
      _noticeIsError = true;
    }
    _restoring = false;
    notifyListeners();
  }

  /// Asks the store what the player owns right now. Returns false if the
  /// store could not be reached; the last known state is kept then.
  Future<bool> _syncOwned() async {
    _syncing = true;
    _premiumSeen = false;
    try {
      await _iap.restorePurchases();
      // The owned purchases reach [_onPurchases] through the stream a moment later.
      await Future<void>.delayed(const Duration(seconds: 2));
      await Wallet.instance.setPremium(active: _premiumSeen);
      return true;
    } catch (e) {
      debugPrint('Checking owned purchases failed: $e');
      return false;
    } finally {
      _syncing = false;
    }
  }

  void clearNotice() => _notice = null;

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      final item = ShopItem.byId(purchase.productID);
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _pendingId = purchase.productID;
          _notice = 'Waiting for the payment to be confirmed…';
          _noticeIsError = false;
          notifyListeners();
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (item != null) {
            if (item.subscription && _syncing) _premiumSeen = true;
            await Wallet.instance.credit(item, purchaseId: purchase.purchaseID);
            if (purchase.status == PurchaseStatus.purchased) {
              _finish(
                notice: switch (item.kind) {
                  ShopItemKind.subscription => 'Premium is on: 2× points, no ads. Thanks for supporting the game!',
                  ShopItemKind.consumable => '+${item.revives} revives. Thanks for supporting the game!',
                  ShopItemKind.owned => 'Ads removed. Thanks for supporting the game!',
                },
              );
            }
            // A revive pack that comes back as "restored" was never consumed
            // (the app closed mid-purchase). Consume it so it can be bought again.
            if (Platform.isAndroid && item.consumable && purchase.status == PurchaseStatus.restored) {
              await _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>().consumePurchase(purchase);
            }
          }
        case PurchaseStatus.error:
          debugPrint('Purchase error: ${purchase.error}');
          _finish(notice: 'The purchase did not go through. Try again later.', error: true);
        case PurchaseStatus.canceled:
          _finish();
      }
      if (purchase.pendingCompletePurchase) await _iap.completePurchase(purchase);
    }
  }

  void _finish({String? notice, bool error = false}) {
    _pendingId = null;
    if (notice != null) {
      _notice = notice;
      _noticeIsError = error;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
