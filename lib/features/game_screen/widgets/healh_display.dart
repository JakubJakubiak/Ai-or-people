import 'package:flutter/material.dart';
import 'package:humanai/utils/app_colors.dart';

class HealthDisplay extends StatelessWidget {
  const HealthDisplay({
    super.key,
    required this.currentHealth,
    required this.maxHealth,
  });

  final int currentHealth;
  final int maxHealth;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$currentHealth of $maxHealth lives left',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List<Widget>.generate(maxHealth, (index) {
          final alive = currentHealth > index;
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: AnimatedScale(
              scale: alive ? 1 : 0.82,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              child: Icon(
                alive ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: alive ? AppColors.heart : AppColors.outline,
                size: 30,
              ),
            ),
          );
        }),
      ),
    );
  }
}
