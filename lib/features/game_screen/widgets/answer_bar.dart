import 'package:flutter/material.dart';
import 'package:humanai/utils/app_colors.dart';

/// The two big answer buttons shown while a round is open.
class AnswerButtons extends StatelessWidget {
  const AnswerButtons({super.key, required this.enabled, required this.onAnswer});

  final bool enabled;

  /// Called with `true` when the player picks "AI".
  final ValueChanged<bool> onAnswer;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _AnswerButton(
            label: 'Human',
            icon: Icons.person_rounded,
            color: AppColors.human,
            onTap: enabled ? () => onAnswer(false) : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _AnswerButton(
            label: 'AI',
            icon: Icons.smart_toy_rounded,
            color: AppColors.ai,
            onTap: enabled ? () => onAnswer(true) : null,
          ),
        ),
      ],
    );
  }
}

class _AnswerButton extends StatefulWidget {
  const _AnswerButton({required this.label, required this.icon, required this.color, required this.onTap});

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  State<_AnswerButton> createState() => _AnswerButtonState();
}

class _AnswerButtonState extends State<_AnswerButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1,
        duration: const Duration(milliseconds: 90),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.lerp(widget.color, Colors.white, 0.22)!, widget.color],
            ),
            boxShadow: [BoxShadow(color: widget.color.withValues(alpha: 0.45), blurRadius: 18, offset: const Offset(0, 6))],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: widget.onTap,
              onHighlightChanged: (down) => setState(() => _pressed = down),
              child: SizedBox(
                height: 72,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(widget.icon, color: AppColors.background, size: 30),
                    const SizedBox(width: 10),
                    Text(widget.label, style: const TextStyle(color: AppColors.background, fontSize: 24, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Replaces the answer buttons after a guess: says whether it was right,
/// explains what to look for, and moves on.
class RevealPanel extends StatelessWidget {
  const RevealPanel({
    super.key,
    required this.correct,
    required this.isAi,
    required this.tip,
    required this.pointsEarned,
    required this.nextLabel,
    required this.onNext,
    this.credit,
    this.autoAdvance,
  });

  final bool correct;
  final bool isAi;
  final String tip;
  final int pointsEarned;
  final String nextLabel;
  final VoidCallback onNext;
  final String? credit;

  /// When set, the button fills up over this time and then advances by itself.
  final Duration? autoAdvance;

  @override
  Widget build(BuildContext context) {
    final color = correct ? AppColors.correct : AppColors.wrong;
    final truth = isAi ? 'made by AI' : 'made by a human';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.7), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(correct ? Icons.check_circle_rounded : Icons.cancel_rounded, color: color, size: 26),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  correct ? 'Correct — $truth' : 'Not quite — $truth',
                  style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              if (correct)
                Text('+$pointsEarned', style: const TextStyle(color: AppColors.combo, fontSize: 17, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.lightbulb_rounded, color: AppColors.combo, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(tip, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.3))),
            ],
          ),
          if (credit != null) ...[
            const SizedBox(height: 6),
            Text(credit!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ],
          const SizedBox(height: 12),
          _NextButton(label: nextLabel, onTap: onNext, autoAdvance: autoAdvance),
        ],
      ),
    );
  }
}

class _NextButton extends StatelessWidget {
  const _NextButton({required this.label, required this.onTap, this.autoAdvance});
  final String label;
  final VoidCallback onTap;
  final Duration? autoAdvance;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceHigh,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (autoAdvance != null)
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: autoAdvance!,
                  builder: (context, t, _) => FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: t,
                    child: ColoredBox(color: Colors.white.withValues(alpha: 0.14)),
                  ),
                ),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
