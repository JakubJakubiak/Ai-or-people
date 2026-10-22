import 'dart:io';

import 'package:flutter/material.dart';
import 'package:humanai/features/shop/shop_items.dart';
import 'package:humanai/features/shop/store_service.dart';
import 'package:humanai/features/shop/wallet.dart';
import 'package:humanai/utils/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

/// The shop: Premium subscription, remove ads and revive packs.
class ShopSheet extends StatelessWidget {
  const ShopSheet({super.key});

  static final _privacyUrl = Uri.parse('https://web-ai-vs-humna.vercel.app/privacy/');
  static final _termsUrl = Uri.parse('https://www.apple.com/legal/internet-services/itunes/dev/stdeula/');
  static Uri get _manageUrl => Platform.isIOS
      ? Uri.parse('https://apps.apple.com/account/subscriptions')
      : Uri.parse('https://play.google.com/store/account/subscriptions?sku=${ShopItem.premium.id}&package=inu.night.humanAI');

  static Future<void> _open(Uri url) async {
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not open $url: $e');
    }
  }

  static Future<void> show(BuildContext context) {
    StoreService.instance.clearNotice();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => const ShopSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreService.instance;
    final wallet = Wallet.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([store, wallet]),
      builder: (context, _) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.outline, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text('Shop', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                  ),
                  _ReviveBalance(revives: wallet.revives),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Support the game and play your way.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 18),
              for (final item in ShopItem.values)
                _ShopTile(
                  item: item,
                  price: switch (store.product(item)?.price) {
                    final price? when item.subscription => '$price/mo',
                    final price => price,
                  },
                  owned: switch (item.kind) {
                    ShopItemKind.subscription => wallet.premium,
                    ShopItemKind.owned => wallet.noAds,
                    ShopItemKind.consumable => false,
                  },
                  busy: store.pendingId == item.id,
                  loading: store.loading,
                  onBuy: store.pendingId == null ? () => store.buy(item) : null,
                ),
              if (!store.loading && !store.available)
                const _Notice(
                  text: 'The shop is not available right now. Check your connection and that you are signed in to the store.',
                  color: AppColors.textMuted,
                )
              else if (store.notice case final notice?)
                _Notice(text: notice, color: store.noticeIsError ? AppColors.wrong : AppColors.correct),
              const SizedBox(height: 4),
              TextButton(
                onPressed: store.available && !store.restoring ? store.restore : null,
                style: TextButton.styleFrom(foregroundColor: Colors.white, textStyle: const TextStyle(fontWeight: FontWeight.w700)),
                child: const Text('Restore purchases'),
              ),
              const Text(
                'Premium renews every month until you cancel it in your store account, at least '
                '24 hours before the end of the period. Revives are kept on this device; Premium and '
                'Remove ads come back with Restore purchases.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.35),
              ),
              const SizedBox(height: 4),
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  if (wallet.premium) _FooterLink(label: 'Manage subscription', onTap: () => _open(_manageUrl)),
                  _FooterLink(label: 'Terms of use', onTap: () => _open(_termsUrl)),
                  _FooterLink(label: 'Privacy policy', onTap: () => _open(_privacyUrl)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textMuted,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, decoration: TextDecoration.underline),
        visualDensity: VisualDensity.compact,
      ),
      child: Text(label),
    );
  }
}

class _ReviveBalance extends StatelessWidget {
  const _ReviveBalance({required this.revives});
  final int revives;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: AppColors.heart.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.favorite_rounded, color: AppColors.heart, size: 18),
          const SizedBox(width: 6),
          Text(
            '$revives ${revives == 1 ? 'revive' : 'revives'}',
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _ShopTile extends StatelessWidget {
  const _ShopTile({
    required this.item,
    required this.price,
    required this.owned,
    required this.busy,
    required this.loading,
    required this.onBuy,
  });

  final ShopItem item;

  /// Price from the store, already formatted in the player's currency.
  final String? price;
  final bool owned;
  final bool busy;
  final bool loading;
  final VoidCallback? onBuy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: item.badge != null ? item.color.withValues(alpha: 0.7) : AppColors.outline),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: item.color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(14)),
              child: Icon(item.icon, color: item.color, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(item.title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                      if (item.badge case final badge?)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: item.color, borderRadius: BorderRadius.circular(6)),
                          child: Text(
                            badge,
                            style: const TextStyle(color: AppColors.background, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.6),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(item.description, style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.3)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _PriceButton(
              price: price,
              owned: owned,
              ownedLabel: item.subscription ? 'Active' : 'Owned',
              busy: busy,
              loading: loading,
              onTap: price == null ? null : onBuy,
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceButton extends StatelessWidget {
  const _PriceButton({
    required this.price,
    required this.owned,
    required this.ownedLabel,
    required this.busy,
    required this.loading,
    required this.onTap,
  });
  final String? price;
  final bool owned;
  final String ownedLabel;
  final bool busy;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (owned) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.correct, size: 20),
            const SizedBox(width: 4),
            Text(ownedLabel, style: const TextStyle(color: AppColors.correct, fontSize: 14, fontWeight: FontWeight.w800)),
          ],
        ),
      );
    }
    return FilledButton(
      onPressed: busy ? null : onTap,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.background,
        disabledBackgroundColor: AppColors.outline,
        disabledForegroundColor: AppColors.textMuted,
        minimumSize: const Size(84, 42),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
      ),
      child: busy || (loading && price == null)
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.textMuted))
          : Text(price ?? '—'),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700, height: 1.35)),
    );
  }
}
