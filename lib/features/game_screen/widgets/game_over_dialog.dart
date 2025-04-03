import 'package:animated_digit/animated_digit.dart';
import 'package:flutter/material.dart';
import 'package:games_services/games_services.dart';
import 'package:humanai/utils/constants.dart'; // Import your constants
import 'package:humanai/utils/gaps.dart';
import 'package:humanai/utils/shared_preferences_helper.dart';

class GameOverDialog extends StatelessWidget {
  const GameOverDialog({
    super.key,
    required this.score,
    required this.onPlayAgain,
    required this.onContinuePlaying,
    required this.limitAdmob,
  });

  final int score;
  final int limitAdmob;
  final VoidCallback onPlayAgain;
  // Keep context passing if GameScreen needs it for ScaffoldMessenger, etc.
  final void Function(BuildContext dialogContext) onContinuePlaying;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Get theme data
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    // Get best score once
    final int bestScore = SharedPreferencesHelper.getBestScore();

    // Create controllers WITHOUT duration/curve
    final scoreController = AnimatedDigitController(score);
    final bestScoreController = AnimatedDigitController(bestScore);

    final bool canContinue = limitAdmob > 0;

    // Define consistent button styles using theme
    final buttonStyle = FilledButton.styleFrom(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );

    final disabledButtonStyle = FilledButton.styleFrom(
      backgroundColor: Colors.grey.shade700, // Clear disabled state
      foregroundColor: Colors.grey.shade400,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );

    return AlertDialog(
      backgroundColor: theme.dialogBackgroundColor, // Use theme background
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
      titlePadding: const EdgeInsets.only(top: 24, bottom: 8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      // insetPadding: EdgeInsets.zero, // Remove or adjust if you don't need edge-to-edge

      title: Text(
        'Game Over',
        textAlign: TextAlign.center,
        // Use theme text styles for consistency
        style: textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface, // Appropriate color from theme
        ),
      ),

      content: Column(
        mainAxisSize: MainAxisSize.min, // Fit content vertically
        children: [
          gapH16,
          Text(
            'Final Score', // Clearer label
            style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          AnimatedDigitWidget(
            controller: scoreController,
            // *** Add duration and curve HERE ***
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            // Make score prominent
            textStyle: textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary, // Use primary color for emphasis
            ),
          ),
          gapH16,
          Text(
            'Best Score', // Clearer label
            style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          AnimatedDigitWidget(
            controller: bestScoreController,
            // *** Add duration and curve HERE ***
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            // Use a slightly different style or secondary color for best score
            textStyle: textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.secondary, // Example: Use secondary color
            ),
          ),
          gapH32, // More space before action buttons

          // --- Action Buttons ---
          Row(
            children: [
              // Continue Button
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.video_camera_back_outlined), // Ad-related icon
                  label: const Text('Continue'),
                  style: canContinue ? buttonStyle : disabledButtonStyle,
                  onPressed: canContinue
                      ? () {
                          // Directly call the callback - GameScreen handles ad logic
                          Navigator.of(context).pop(); // Close this dialog first
                          onContinuePlaying(context); // Call function from GameScreen
                        }
                      : null, // Button is disabled if !canContinue
                ),
              ),
              gapW12, // Space between buttons
              // Leaderboard Button (Icon only for compactness)
              FilledButton(
                style: buttonStyle.copyWith(padding: MaterialStateProperty.all(const EdgeInsets.all(12))), // Make it more square
                onPressed: () async {
                  // Mark async
                  // Optional: Pop dialog before showing leaderboard?
                  // Navigator.of(context).pop();
                  try {
                    if (!await GamesServices.isSignedIn) {
                      await GamesServices.signIn(); // Try signing in if not already
                    }
                    // Use constants for IDs
                    await Leaderboards.showLeaderboards(
                      androidLeaderboardID: Constants.androidLeaderboardId,
                      iOSLeaderboardID: Constants.iosLeaderboardId,
                    );
                  } catch (e) {
                    print("Error showing leaderboard from dialog: $e");
                    // Optional: Show a snackbar if context is available
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not display Leaderboards.")));
                    }
                  }
                },
                child: const Icon(Icons.leaderboard_outlined, size: 28),
              ),
            ],
          ),
          // Conditionally show info text if cannot continue
          if (!canContinue)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                "No continues remaining today.", // Inform user
                style: textTheme.bodySmall?.copyWith(color: Colors.grey.shade500),
                textAlign: TextAlign.center,
              ),
            ),

          gapH16,

          // Play Again Button (Full Width for clarity)
          SizedBox(
            width: double.infinity, // Stretch full width
            child: FilledButton.icon(
              icon: const Icon(Icons.replay_outlined),
              label: const Text('Play Again'),
              style: buttonStyle, // Use the defined style
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                onPlayAgain(); // Trigger play again action
              },
            ),
          ),
          gapH8, // Bottom padding inside the content area
        ],
      ),
    );
  }
}
