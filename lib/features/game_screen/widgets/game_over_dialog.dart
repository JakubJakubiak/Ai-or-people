import 'package:flutter/material.dart';
import 'package:games_services/games_services.dart';
import 'package:humanai/utils/shared_preferences_helper.dart';

class GameOverDialog extends StatelessWidget {
  const GameOverDialog({
    super.key,
    required this.score,
    required this.onPlayAgain,
    required this.onContinuePlaying,
  });

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
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: () async {
                        // show confirmation dialog
                        final outerContext = context;
                        await showDialog<AlertDialog>(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: const Text('Continue Playing?'),
                              content: const Text(
                                'Watch an ad to continue playing?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: const Text('No'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    Navigator.of(outerContext).pop();
                                    onContinuePlaying();
                                  },
                                  child: const Text('Yes'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(
                            Icons.play_arrow,
                            size: 48,
                          ),
                          Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    child: const Icon(Icons.leaderboard, size: 42),
                    onPressed: () => Leaderboards.showLeaderboards(
                      androidLeaderboardID: 'CgkI9JqZ6Z8VEAIQAA',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onPlayAgain();
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.replay,
                      size: 42,
                    ),
                    SizedBox(width: 16),
                    Text(
                      'Play Again',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
