import 'package:flutter/material.dart';
import 'package:humanai/utils/app_colors.dart';

/// How a shop item behaves once bought.
enum ShopItemKind {
  /// Bought once, owned forever ("Remove ads").
  owned,

  /// Used up and bought again (revive packs).
  consumable,

  /// Renews every month until cancelled (Premium).
  subscription,
}

/// Everything the shop sells. The ids must match the products created in
/// Google Play Console and App Store Connect.
enum ShopItem {
  premium(
    id: 'premium',
    kind: ShopItemKind.subscription,
    title: 'Premium',
    description: '2× points in every run, no ads and a free revive each game.',
    icon: Icons.bolt_rounded,
    color: AppColors.combo,
    badge: '2× POINTS',
  ),
  noAds(
    id: 'no_ads',
    kind: ShopItemKind.owned,
    title: 'Remove ads',
    description: 'No more banner ads. One-time purchase.',
    icon: Icons.block_rounded,
    color: AppColors.ai,
  ),
  revives5(
    id: 'revives_5',
    kind: ShopItemKind.consumable,
    title: '5 revives',
    description: 'Get all lives back after a game over, without an ad.',
    icon: Icons.favorite_rounded,
    color: AppColors.heart,
    revives: 5,
  ),
  revives20(
    id: 'revives_20',
    kind: ShopItemKind.consumable,
    title: '20 revives',
    description: 'Best value for long runs and high scores.',
    icon: Icons.volunteer_activism_rounded,
    color: AppColors.heart,
    revives: 20,
    badge: 'BEST VALUE',
  );

  const ShopItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.revives = 0,
    this.badge,
  });

  /// Product id in the stores.
  final String id;
  final ShopItemKind kind;
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  /// Revives added by one purchase of a revive pack.
  final int revives;
  final String? badge;

  bool get consumable => kind == ShopItemKind.consumable;
  bool get subscription => kind == ShopItemKind.subscription;

  static Set<String> get ids => {for (final item in values) item.id};

  static ShopItem? byId(String id) {
    for (final item in values) {
      if (item.id == id) return item;
    }
    return null;
  }
}
