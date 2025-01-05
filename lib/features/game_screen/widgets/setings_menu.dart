import 'package:flutter/material.dart';
import 'package:humanai/features/game_screen/game_screen.dart';

class SettingsMenu extends StatelessWidget {
  final int score;
  final Function(Color) onColorChanged;

  const SettingsMenu({
    super.key,
    required this.score,
    required this.onColorChanged,
    required Null Function(dynamic ThemeMode) onThemeChanged,
    // required Null Function(dynamic ThemeMode) onThemeChanged,
  });

  void _updateTheme(BuildContext context, Color color) {
    onColorChanged(color);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Settings'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Score: $score'),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ThemeButton(
                color: Colors.pink,
                onPressed: () => _updateTheme(context, Colors.pink),
              ),
              _ThemeButton(
                color: Colors.blue,
                onPressed: () => _updateTheme(context, Colors.blue),
              ),
              _ThemeButton(
                color: Colors.amber,
                onPressed: () => _updateTheme(context, Colors.amber),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeButton extends StatelessWidget {
  final Color color;
  final VoidCallback onPressed;

  const _ThemeButton({
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.circle, color: color, size: 40),
      onPressed: onPressed,
    );
  }
}
