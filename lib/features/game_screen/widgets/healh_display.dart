import 'package:flutter/material.dart';

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
    return Row(
      children: List<Widget>.generate(maxHealth, (index) {
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Icon(
            currentHealth > index ? Icons.favorite : Icons.favorite_border,
            color: Colors.pink,
            size: 36,
          ),
        );
      }),
    );
  }
}
