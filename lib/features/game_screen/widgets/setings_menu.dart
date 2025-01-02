import 'package:flutter/material.dart';
import 'package:games_services/games_services.dart';
import 'package:humanai/utils/gaps.dart';
import 'package:humanai/utils/shared_preferences_helper.dart';

class SettingsMenu extends StatelessWidget {
  const SettingsMenu({
    super.key,
    required this.score,
    required this.onThemeChanged,
  });

  final int score;
  final void Function(ThemeMode) onThemeChanged;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Settings',
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
                gapW16,
                Expanded(
                  child: SizedBox(
                    height: Sizes.p48,
                    child: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode),
                        ),
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.brightness_auto),
                        ),
                      ],
                      selected: {Theme.of(context).brightness == Brightness.light ? ThemeMode.light : ThemeMode.dark},
                      onSelectionChanged: (Set<ThemeMode> selection) {
                        onThemeChanged(selection.first);
                      },
                    ),
                  ),
                ),
                gapW16,
              ],
            ),
            gapH16,
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.replay,
                      size: 42,
                    ),
                    gapW16,
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
