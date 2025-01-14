import 'package:flutter/material.dart';
import 'dart:math' as math;

class AnimatedPixelFlameCombo extends StatefulWidget {
  final double comboCount;
  final double size;

  const AnimatedPixelFlameCombo({
    Key? key,
    required this.comboCount,
    this.size = 100,
  }) : super(key: key);

  @override
  State<AnimatedPixelFlameCombo> createState() => _AnimatedPixelFlameComboState();
}

class _AnimatedPixelFlameComboState extends State<AnimatedPixelFlameCombo> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(alignment: Alignment.center, children: [
          CustomPaint(
            size: Size(widget.size, widget.size * 1.1),
            painter: AnimatedPixelFlamePainter(
              animation: _controller,
            ),
          ),
          Column(
            children: [
              const Text('Combo'),
              Text(
                '${widget.comboCount.toString()}',
                style: TextStyle(
                  fontSize: widget.size * 0.4,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.5),
                      offset: Offset(2, 2),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            ],
          )
        ]);
      },
    );
  }
}

class AnimatedPixelFlamePainter extends CustomPainter {
  final Animation<double> animation;

  AnimatedPixelFlamePainter({required this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF40E0D0), // Cyan
          Color(0xFF0080FF), // Blue
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final pixelSize = size.width / 12;
    final time = animation.value * 2 * math.pi;

    // Base coordinates for the flame shape
    final baseCoordinates = [
      [6, 0], // Top center
      [8, 1], // Top right
      [9, 2],
      [10, 4],
      [11, 6],
      [10, 8],
      [9, 9],
      [8, 10],
      [6, 11], // Bottom center
      [4, 10],
      [3, 9],
      [2, 8],
      [1, 6],
      [2, 4],
      [3, 2],
      [4, 1], // Top left
    ];

    // Animate coordinates
    final animatedCoordinates = baseCoordinates.map((point) {
      double x = point[0].toDouble();
      double y = point[1].toDouble();

      // Add wave motion
      if (y < 8) {
        // Only animate upper part of flame
        x += math.sin(time + y * 0.5) * 0.3; // Horizontal wave
        y += math.cos(time * 0.8 + x * 0.3) * 0.2; // Vertical wave
      }

      return [x, y];
    }).toList();

    final path = Path()

      // Draw animated flame shape
      ..moveTo(
        animatedCoordinates[0][0] * pixelSize,
        animatedCoordinates[0][1] * pixelSize,
      );

    for (int i = 1; i < animatedCoordinates.length; i++) {
      path.lineTo(
        animatedCoordinates[i][0] * pixelSize,
        animatedCoordinates[i][1] * pixelSize,
      );
    }

    path.close();
    canvas.drawPath(path, paint);

    // Draw pixel grid
    final pixelPaint = Paint()
      ..color = const Color.fromARGB(0, 0, 0, 0).withValues()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Vertical lines
    for (double x = 0; x <= size.width; x += pixelSize) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        pixelPaint,
      );
    }

    // Horizontal lines
    for (double y = 0; y <= size.height; y += pixelSize) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        pixelPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
