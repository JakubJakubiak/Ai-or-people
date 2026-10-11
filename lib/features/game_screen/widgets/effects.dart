import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:humanai/utils/app_colors.dart';

/// Animated flame that shows the current combo multiplier.
///
/// It grows and changes colour as the combo rises: a small ember at x1.0,
/// orange fire while the streak builds, and violet plasma on a long streak.
class ComboFlame extends StatefulWidget {
  const ComboFlame({super.key, required this.boost, this.size = 54});

  final double boost;
  final double size;

  @override
  State<ComboFlame> createState() => _ComboFlameState();
}

class _ComboFlameState extends State<ComboFlame> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 0 at x1.0, 1 from x5.0 up.
    final level = ((widget.boost - 1) / 4).clamp(0.0, 1.0);
    return Semantics(
      label: 'Combo multiplier ${widget.boost.toStringAsFixed(1)}',
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: level),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
        builder: (context, animatedLevel, child) => SizedBox(
          width: widget.size * 1.3,
          height: widget.size * 1.35,
          child: Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: CustomPaint(painter: _FlamePainter(_controller, animatedLevel))),
              child!,
            ],
          ),
        ),
        child: TweenAnimationBuilder<double>(
          // A new key replays the "pop" whenever the multiplier changes.
          key: ValueKey(widget.boost),
          tween: Tween(begin: widget.boost > 1 ? 1.5 : 0.8, end: 1),
          duration: const Duration(milliseconds: 420),
          curve: Curves.elasticOut,
          builder: (context, scale, child) => Transform.scale(scale: scale, alignment: Alignment.bottomCenter, child: child),
          child: Text(
            'x${widget.boost.toStringAsFixed(1)}',
            style: TextStyle(
              color: Colors.white,
              fontSize: widget.size * 0.36,
              fontWeight: FontWeight.w900,
              height: 1,
              shadows: const [
                Shadow(color: Colors.black, blurRadius: 6),
                Shadow(color: Colors.black, blurRadius: 2, offset: Offset(0, 1)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FlamePainter extends CustomPainter {
  _FlamePainter(this.animation, this.level) : super(repaint: animation);

  final Animation<double> animation;
  final double level;

  static const _ember = [Color(0xFFB45309), Color(0xFFF59E0B), Color(0xFFFDE68A)];
  static const _fire = [Color(0xFFFF3D2E), Color(0xFFFF8A00), Color(0xFFFFF3B0)];
  static const _plasma = [Color(0xFF7C3AED), Color(0xFFEC4899), Color(0xFFFFE4F3)];

  Color _layerColor(int layer) {
    if (level < 0.6) return Color.lerp(_ember[layer], _fire[layer], level / 0.6)!;
    return Color.lerp(_fire[layer], _plasma[layer], (level - 0.6) / 0.4)!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value * 2 * math.pi;
    final base = Offset(size.width / 2, size.height * 0.8);
    final height = size.height * (0.56 + 0.3 * level);
    final width = size.width * (0.56 + 0.24 * level);
    final strength = 0.75 + 0.25 * level;

    // Soft glow behind the flame.
    final glowCenter = base - Offset(0, height * 0.4);
    final glowRadius = width * 1.1;
    canvas.drawCircle(
      glowCenter,
      glowRadius,
      Paint()
        ..shader = RadialGradient(colors: [_layerColor(0).withValues(alpha: 0.45 * strength), _layerColor(0).withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: glowCenter, radius: glowRadius)),
    );

    const scales = [1.0, 0.68, 0.36];
    for (var layer = 0; layer < 3; layer++) {
      final phase = layer * 1.7;
      final s = scales[layer];
      final flicker = 1 + 0.09 * math.sin(t * 3 + phase) + 0.05 * math.sin(t * 7 + phase * 2);
      final sway = math.sin(t * 2 + phase) * width * 0.16 * s;
      final path = _flame(base, width * s, height * s * flicker, sway, math.sin(t * 4 + phase) * width * 0.05 * s);
      canvas.drawPath(path, Paint()..color = _layerColor(layer).withValues(alpha: layer == 0 ? 0.92 * strength + 0.08 : 1));
    }

    // Sparks flying up; more of them the hotter the combo.
    final sparks = 4 + (level * 8).round();
    for (var k = 0; k < sparks; k++) {
      final seed = (math.sin(k * 12.9898) * 43758.5453).abs() % 1;
      final life = (animation.value * (1 + (k % 3)) + seed) % 1;
      final x = base.dx + (seed - 0.5) * width * 1.3 + math.sin(t * 2 + k) * 3;
      final y = base.dy - height * 0.35 - life * height * 1.05;
      canvas.drawCircle(Offset(x, y), (1 - life) * (1.4 + level * 1.4), Paint()..color = _layerColor(2).withValues(alpha: (1 - life) * strength));
    }
  }

  Path _flame(Offset base, double w, double h, double sway, double wobble) {
    final tip = Offset(base.dx + sway, base.dy - h);
    final left = Offset(base.dx - w * 0.5, base.dy - h * 0.2);
    final right = Offset(base.dx + w * 0.5, base.dy - h * 0.2);
    return Path()
      ..moveTo(left.dx, left.dy)
      ..cubicTo(base.dx - w * 0.66 - wobble, base.dy - h * 0.55, base.dx - w * 0.12 + sway * 0.6, base.dy - h * 0.68, tip.dx, tip.dy)
      ..cubicTo(base.dx + w * 0.12 + sway * 0.6, base.dy - h * 0.68, base.dx + w * 0.66 - wobble, base.dy - h * 0.55, right.dx, right.dy)
      ..cubicTo(right.dx, base.dy + h * 0.1, left.dx, base.dy + h * 0.1, left.dx, left.dy)
      ..close();
  }

  @override
  bool shouldRepaint(_FlamePainter oldDelegate) => oldDelegate.level != level;
}

/// One-shot burst of sparks, played over the card after a correct answer.
class SparkBurst extends StatelessWidget {
  const SparkBurst({super.key, required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) => CustomPaint(painter: _BurstPainter(t, color), size: Size.infinite),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.t, this.color);
  final double t;
  final Color color;

  static const _count = 36;

  @override
  void paint(Canvas canvas, Size size) {
    if (t >= 1) return;
    final center = Offset(size.width / 2, size.height * 0.55);
    final reach = size.shortestSide * 0.62;
    for (var i = 0; i < _count; i++) {
      final seed = (math.sin(i * 78.233) * 43758.5453).abs() % 1;
      final angle = i / _count * 2 * math.pi + seed;
      final distance = reach * t * (0.45 + 0.55 * seed);
      // Gravity pulls the sparks down a little as they fade.
      final position = center + Offset(math.cos(angle), math.sin(angle)) * distance + Offset(0, 60 * t * t);
      final paint = Paint()..color = (i.isEven ? color : Colors.white).withValues(alpha: (1 - t) * 0.95);
      final length = 10 * (1 - t) + 3;
      canvas
        ..save()
        ..translate(position.dx, position.dy)
        ..rotate(angle)
        ..drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: length, height: 4), const Radius.circular(2)), paint)
        ..restore();
    }
    // Expanding ring.
    canvas.drawCircle(
      center,
      reach * 0.9 * t,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5 * (1 - t)
        ..color = color.withValues(alpha: (1 - t) * 0.6),
    );
  }

  @override
  bool shouldRepaint(_BurstPainter oldDelegate) => oldDelegate.t != t;
}

/// Shakes its child sideways once when [trigger] changes to a new value.
class Shake extends StatelessWidget {
  const Shake({super.key, required this.trigger, required this.child});

  /// Pass `null` for "no shake"; any new non-null value plays the animation.
  final Object? trigger;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (trigger == null) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey(trigger),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 480),
      builder: (context, t, child) => Transform.translate(
        offset: Offset(math.sin(t * math.pi * 6) * 12 * (1 - t), 0),
        child: child,
      ),
      child: child,
    );
  }
}

/// "+12" that floats up and fades out next to the score.
class FloatingPoints extends StatelessWidget {
  const FloatingPoints({super.key, required this.points});
  final int points;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1100),
        curve: Curves.easeOut,
        builder: (context, t, child) => Opacity(
          opacity: t < 0.7 ? 1 : (1 - t) / 0.3,
          child: Transform.translate(offset: Offset(0, -26 * t), child: Transform.scale(scale: 0.8 + 0.4 * math.min(1, t * 4), child: child)),
        ),
        child: Text(
          '+$points',
          style: const TextStyle(
            color: AppColors.combo,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: Colors.black, blurRadius: 6)],
          ),
        ),
      ),
    );
  }
}

/// Slow drifting colour glows behind the game; they warm up with the combo.
class LivingBackground extends StatefulWidget {
  const LivingBackground({super.key, required this.heat, required this.child});

  /// 0 = calm, 1 = long combo streak.
  final double heat;
  final Widget child;

  @override
  State<LivingBackground> createState() => _LivingBackgroundState();
}

class _LivingBackgroundState extends State<LivingBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: widget.heat),
      duration: const Duration(milliseconds: 900),
      builder: (context, heat, child) => CustomPaint(painter: _BackgroundPainter(_controller, heat), child: child),
      child: widget.child,
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  _BackgroundPainter(this.animation, this.heat) : super(repaint: animation);
  final Animation<double> animation;
  final double heat;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..shader = AppColors.backgroundGradient.createShader(rect));
    final t = animation.value * 2 * math.pi;

    void glow(Offset center, double radius, Color color, double alpha) {
      canvas.drawCircle(
        center,
        radius,
        Paint()..shader = RadialGradient(colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    glow(Offset(size.width * (0.15 + 0.12 * math.sin(t)), size.height * (0.2 + 0.06 * math.cos(t))), size.width * 0.9, AppColors.human, 0.13);
    glow(Offset(size.width * (0.9 + 0.1 * math.cos(t * 2)), size.height * (0.75 + 0.08 * math.sin(t))), size.width, AppColors.ai, 0.16);
    if (heat > 0) {
      final fire = Color.lerp(const Color(0xFFFF8A00), const Color(0xFF7C3AED), ((heat - 0.6) / 0.4).clamp(0, 1))!;
      glow(Offset(size.width * (0.72 + 0.05 * math.sin(t * 3)), size.height * 0.1), size.width * 0.85, fire, 0.26 * heat);
    }
  }

  @override
  bool shouldRepaint(_BackgroundPainter oldDelegate) => oldDelegate.heat != heat;
}
