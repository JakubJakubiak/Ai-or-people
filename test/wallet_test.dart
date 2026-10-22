import 'package:flutter_test/flutter_test.dart';
import 'package:humanai/features/shop/shop_items.dart';
import 'package:humanai/features/shop/wallet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Wallet wallet;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    wallet = Wallet(await SharedPreferences.getInstance());
  });

  test('starts with ads and no revives', () {
    expect(wallet.noAds, isFalse);
    expect(wallet.revives, 0);
  });

  test('revive packs add up', () async {
    expect(await wallet.credit(ShopItem.revives5, purchaseId: 'GPA.1'), isTrue);
    expect(await wallet.credit(ShopItem.revives20, purchaseId: 'GPA.2'), isTrue);
    expect(wallet.revives, 25);
  });

  test('the same purchase is paid out once', () async {
    await wallet.credit(ShopItem.revives5, purchaseId: 'GPA.1');
    expect(await wallet.credit(ShopItem.revives5, purchaseId: 'GPA.1'), isFalse);
    expect(wallet.revives, 5);
  });

  test('remove ads is owned, not counted', () async {
    expect(await wallet.credit(ShopItem.noAds, purchaseId: 'GPA.3'), isTrue);
    expect(wallet.noAds, isTrue);
    expect(await wallet.credit(ShopItem.noAds), isFalse);
    expect(wallet.revives, 0);
  });

  test('using a revive needs one', () async {
    expect(await wallet.useRevive(), isFalse);
    await wallet.credit(ShopItem.revives5, purchaseId: 'GPA.4');
    expect(await wallet.useRevive(), isTrue);
    expect(wallet.revives, 4);
  });

  test('state survives a restart', () async {
    await wallet.credit(ShopItem.noAds, purchaseId: 'GPA.5');
    await wallet.credit(ShopItem.revives5, purchaseId: 'GPA.6');
    final again = Wallet(await SharedPreferences.getInstance());
    expect(again.noAds, isTrue);
    expect(again.revives, 5);
  });

  test('premium follows the store and removes ads', () async {
    expect(await wallet.credit(ShopItem.premium, purchaseId: 'GPA.7'), isTrue);
    expect(wallet.premium, isTrue);
    expect(wallet.adFree, isTrue);
    expect(wallet.noAds, isFalse);
    await wallet.setPremium(active: false);
    expect(wallet.adFree, isFalse);
  });

  test('product ids match the store setup', () {
    expect(ShopItem.ids, {'premium', 'no_ads', 'revives_5', 'revives_20'});
    expect(ShopItem.premium.subscription, isTrue);
    expect(ShopItem.byId('revives_20'), ShopItem.revives20);
    expect(ShopItem.byId('unknown'), isNull);
    expect(ShopItem.noAds.consumable, isFalse);
  });
}
