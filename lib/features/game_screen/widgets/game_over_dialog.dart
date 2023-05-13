import 'package:flutter/material.dart';
import 'package:humanai/utils/shared_preferences_helper.dart';

class GameOverDialog extends StatelessWidget {
  const GameOverDialog(
      {super.key,
      required this.score,
      required this.onPlayAgain,
      required this.onContinuePlaying});

  final int score;
  final VoidCallback onPlayAgain;
  final VoidCallback onContinuePlaying;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Game Over',
        textAlign: TextAlign.center,
      ),
      titleTextStyle: const TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
      insetPadding: EdgeInsets.zero,
      content: FractionallySizedBox(
        heightFactor: 0.7,
        child: Column(
          children: [
            const Spacer(),
            const Text(
              'Score',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '$score',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'Your Best',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              SharedPreferencesHelper.getBestScore().toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onContinuePlaying();
              },
              icon: const Icon(
                Icons.play_arrow,
                size: 48,
              ),
              label: const Text(
                'Continue',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onPlayAgain();
          },
          child: const Text('Start Again'),
        ),
      ],
    );
  }
}
