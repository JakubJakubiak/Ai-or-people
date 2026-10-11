import 'package:animated_digit/animated_digit.dart';
import 'package:flutter/material.dart';
import 'package:games_services/games_services.dart';
import 'package:humanai/features/game_screen/game_screen.dart' show RoundStats;
import 'package:humanai/models/game_item.dart';
import 'package:humanai/utils/app_colors.dart';
import 'package:humanai/utils/constants.dart';
import 'package:humanai/utils/shared_preferences_helper.dart';

class GameOverDialog extends StatelessWidget {
  const GameOverDialog({
    super.key,
    required this.score,
    required this.isNewBest,
    required this.stats,
    required this.onPlayAgain,
    required this.onContinuePlaying,
    required this.limitAdmob,
  });

  final int score;
  final bool isNewBest;
  final Map<MediaType, RoundStats> stats;
  final int limitAdmob;
  final VoidCallback onPlayAgain;
  final VoidCallback onContinuePlaying;

  static const _typeLabels = {
    MediaType.image: ('Images', Icons.image_rounded),
    MediaType.video: ('Videos', Icons.videocam_rounded),
    MediaType.music: ('Music', Icons.music_note_rounded),
  };

  Future<void> _showLeaderboard(BuildContext context) async {
    try {
      if (!await GamesServices.isSignedIn) await GamesServices.signIn();
      await Leaderboards.showLeaderboards(
        androidLeaderboardID: Constants.androidLeaderboardId,
        iOSLeaderboardID: Constants.iosLeaderboardId,
      );
    } catch (e) {
      debugPrint('Error showing leaderboard from dialog: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Leaderboards are not available right now.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bestScore = SharedPreferencesHelper.getBestScore();
    final canContinue = limitAdmob > 0;
    final total = stats.values.fold<int>(0, (n, s) => n + s.total);
    final correct = stats.values.fold<int>(0, (n, s) => n + s.correct);

    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Game over',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            Center(
              child: AnimatedDigitWidget(
                controller: AnimatedDigitController(score),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                textStyle: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w900, height: 1),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: isNewBest
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(color: AppColors.combo.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.emoji_events_rounded, color: AppColors.combo, size: 18),
                          SizedBox(width: 6),
                          Text('New best score!', style: TextStyle(color: AppColors.combo, fontSize: 14, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    )
                  : Text('Best $bestScore', style: const TextStyle(color: AppColors.textMuted, fontSize: 15, fontWeight: FontWeight.w600)),
            ),
            if (total > 0) ...[
              const SizedBox(height: 20),
              Text(
                'YOU SPOTTED $correct OF $total',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2),
              ),
              const SizedBox(height: 10),
              for (final type in MediaType.values)
                if (stats[type] case final s? when s.total > 0)
                  _AccuracyRow(label: _typeLabels[type]!.$1, icon: _typeLabels[type]!.$2, correct: s.correct, total: s.total),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              icon: const Icon(Icons.replay_rounded),
              label: const Text('Play again'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.background,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                onPlayAgain();
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.favorite_rounded, size: 20),
                    label: const Text('Continue · watch ad'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.heart,
                      disabledForegroundColor: AppColors.outline,
                      side: BorderSide(color: canContinue ? AppColors.heart : AppColors.outline),
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    onPressed: canContinue
                        ? () {
                            Navigator.of(context).pop();
                            onContinuePlaying();
                          }
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.outline),
                    minimumSize: const Size(54, 50),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => _showLeaderboard(context),
                  child: const Icon(Icons.leaderboard_rounded, semanticLabel: 'Leaderboard'),
                ),
              ],
            ),
            if (!canContinue)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'No continues remaining today.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AccuracyRow extends StatelessWidget {
  const _AccuracyRow({required this.label, required this.icon, required this.correct, required this.total});
  final String label;
  final IconData icon;
  final int correct;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ratio = correct / total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          SizedBox(width: 62, child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 10,
                backgroundColor: AppColors.surfaceHigh,
                color: ratio >= 0.5 ? AppColors.correct : AppColors.wrong,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 40,
            child: Text('$correct/$total', textAlign: TextAlign.right, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
