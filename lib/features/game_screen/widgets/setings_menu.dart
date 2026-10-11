import 'package:flutter/material.dart';
import 'package:humanai/features/game_screen/streak_service.dart';
import 'package:humanai/features/game_screen/widgets/daily_raking.dart';
import 'package:humanai/features/game_screen/widgets/how_to_play.dart';
import 'package:humanai/models/game_item.dart';
import 'package:humanai/utils/app_colors.dart';

/// Settings dialog. Pops with the set of content types the player selected.
class SettingsMenu extends StatefulWidget {
  const SettingsMenu({
    super.key,
    required this.enabledTypes,
    required this.availableTypes,
  });

  final Set<MediaType> enabledTypes;

  /// Types that actually have content loaded; the others are greyed out.
  final Set<MediaType> availableTypes;

  @override
  State<SettingsMenu> createState() => _SettingsMenuState();
}

class _SettingsMenuState extends State<SettingsMenu> {
  late final Set<MediaType> _selected = {...widget.enabledTypes};

  static const _labels = {
    MediaType.image: ('Images', Icons.image_rounded),
    MediaType.video: ('Videos', Icons.videocam_rounded),
    MediaType.music: ('Music', Icons.music_note_rounded),
  };

  void _toggle(MediaType type) {
    setState(() {
      if (!_selected.remove(type)) {
        _selected.add(type);
      } else if (_selected.isEmpty) {
        _selected.add(type); // at least one kind of content has to stay on
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final streak = StreakService.instance.getCurrentStreak();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_selected);
      },
      child: Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Settings', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 18),
              const Text(
                'WHAT DO YOU WANT TO PRACTISE?',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2),
              ),
              const SizedBox(height: 10),
              for (final type in MediaType.values)
                _TypeTile(
                  label: _labels[type]!.$1,
                  icon: _labels[type]!.$2,
                  selected: _selected.contains(type),
                  available: widget.availableTypes.contains(type),
                  onTap: () => _toggle(type),
                ),
              const SizedBox(height: 8),
              const Divider(color: AppColors.outline, height: 24),
              _LinkTile(
                icon: Icons.local_fire_department_rounded,
                label: streak > 0 ? 'Daily streak: $streak ${streak == 1 ? 'day' : 'days'}' : 'Daily streak',
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) => SlidingMenuWidget(consecutiveDays: streak, onClose: () => Navigator.pop(context)),
                ),
              ),
              _LinkTile(
                icon: Icons.help_outline_rounded,
                label: 'How to play',
                onTap: () => HowToPlayDialog.show(context),
              ),
              const SizedBox(height: 10),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.background,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                onPressed: () => Navigator.of(context).pop(_selected),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({required this.label, required this.icon, required this.selected, required this.available, required this.onTap});
  final String label;
  final IconData icon;
  final bool selected;
  final bool available;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final on = selected && available;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: on ? AppColors.surfaceHigh : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: on ? AppColors.human : AppColors.outline, width: on ? 1.5 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: available ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: available ? Colors.white : AppColors.outline, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    available ? label : '$label (unavailable)',
                    style: TextStyle(color: available ? Colors.white : AppColors.outline, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                Icon(
                  on ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: on ? AppColors.human : AppColors.outline,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textMuted, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600))),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
