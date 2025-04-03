import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' as ui; // Import for ui.Gradient

class AnimatedPixelFlameCombo extends StatefulWidget {
  final double comboCount; // Keep as double to handle values like 1.2
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
      // Slightly faster animation
      duration: const Duration(milliseconds: 1200),
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
    // Format the double to always show one decimal place
    final String displayCount = widget.comboCount.toStringAsFixed(1);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(alignment: Alignment.center, children: [
          CustomPaint(
            // Adjust size slightly for better flame shape fit if needed
            size: Size(widget.size, widget.size * 1.2), // Increased height slightly
            painter: AnimatedPixelFlamePainter(
              animation: _controller,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min, // Constrain column height
            children: [
              Text(
                'Combo', // Changed text
                style: TextStyle(
                  fontSize: widget.size * 0.15, // Smaller title
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    // Outline effect
                    Shadow(color: Colors.black.withOpacity(0.8), offset: Offset(-1.5, -1.5), blurRadius: 1),
                    Shadow(color: Colors.black.withOpacity(0.8), offset: Offset(1.5, -1.5), blurRadius: 1),
                    Shadow(color: Colors.black.withOpacity(0.8), offset: Offset(1.5, 1.5), blurRadius: 1),
                    Shadow(color: Colors.black.withOpacity(0.8), offset: Offset(-1.5, 1.5), blurRadius: 1),
                  ],
                ),
              ),
              Text(
                displayCount, // Display formatted count (e.g., "1.2", "10.0")
                style: TextStyle(
                  fontSize: widget.size * 0.45, // Adjust if needed for wider text
                  fontWeight: FontWeight.w900, // Bolder
                  color: Colors.white,
                  shadows: [
                    // Stronger outline/shadow
                    Shadow(color: Colors.black.withOpacity(0.8), offset: Offset(-2, -2), blurRadius: 2),
                    Shadow(color: Colors.black.withOpacity(0.8), offset: Offset(2, -2), blurRadius: 2),
                    Shadow(color: Colors.black.withOpacity(0.8), offset: Offset(2, 2), blurRadius: 2),
                    Shadow(color: Colors.black.withOpacity(0.8), offset: Offset(-2, 2), blurRadius: 2),
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

// --- AnimatedPixelFlamePainter remains the same as the previous version ---
// (Includes flame colors, true pixelation, inner glow, animation polish)
class AnimatedPixelFlamePainter extends CustomPainter {
  final Animation<double> animation;
  // Define grid size - higher number means smaller pixels
  final int pixelGridSizeX = 14;
  final int pixelGridSizeY = 16; // Allow slightly taller grid

  AnimatedPixelFlamePainter({required this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final double pixelWidth = size.width / pixelGridSizeX;
    final double pixelHeight = size.height / pixelGridSizeY;

    final time = animation.value * 2 * math.pi;

    // --- Define Flame Paints ---
    final Paint outerFlamePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(size.width / 2, 0), // Top center
        Offset(size.width / 2, size.height * 0.9), // Lower center
        [
          const Color(0xFFFFE082), // Light Yellow
          const Color(0xFFFF8A65), // Orange
          const Color(0xFFE64A19), // Deep Orange/Red
        ],
        [0.0, 0.5, 1.0], // Gradient stops
      );

    final Paint innerFlamePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(size.width / 2, size.height * 0.3), // Starts higher
        Offset(size.width / 2, size.height), // Ends at bottom
        [
          const Color(0xFFFFFDE7), // Very Light Yellow / Whiteish
          const Color(0xFFFFCC80), // Lighter Orange
        ],
        [0.0, 1.0],
      );

    // --- Base coordinates (adjusted for a ~14x16 grid) ---
    final baseCoordinates = [
      [7, 0], // Top center (using pixelGridSizeX / 2)
      [9, 1],
      [10, 2],
      [11, 4],
      [12.5, 7], // Wider point
      [11, 10],
      [10, 12],
      [9, 13],
      [7, 15], // Bottom center (near pixelGridSizeY - 1)
      [5, 13],
      [4, 12],
      [3, 10],
      [1.5, 7], // Wider point
      [3, 4],
      [4, 2],
      [5, 1],
    ];

    // --- Calculate Animated Path (for collision detection) ---
    final path = Path();
    final List<Offset> animatedPoints = [];

    for (var point in baseCoordinates) {
      double x = point[0].toDouble();
      double y = point[1].toDouble();
      // More movement towards the top/middle, less at the base
      double magnitudeFactor = 1.0 - math.pow(y / pixelGridSizeY, 1.5).toDouble();

      // Add wave motion
      if (y < pixelGridSizeY * 0.8) {
        // Animate most of the flame
        // Slightly more complex wave interaction
        x += math.sin(time * 1.3 + y * 0.5) * 0.5 * magnitudeFactor;
        y += math.cos(time * 0.9 + x * 0.4) * 0.4 * magnitudeFactor;
      }
      // Clamp values to prevent extreme distortion (optional)
      x = x.clamp(0.0, pixelGridSizeX.toDouble());
      y = y.clamp(0.0, pixelGridSizeY.toDouble());

      // Convert grid coordinates to canvas coordinates
      animatedPoints.add(Offset(x * pixelWidth, y * pixelHeight));
    }

    if (animatedPoints.isNotEmpty) {
      path.moveTo(animatedPoints[0].dx, animatedPoints[0].dy);
      for (int i = 1; i < animatedPoints.length; i++) {
        path.lineTo(animatedPoints[i].dx, animatedPoints[i].dy);
      }
      path.close();
    } else {
      // Avoid errors if animatedPoints is somehow empty
      return;
    }

    // --- Draw Pixelated Flame ---
    final random = math.Random();
    for (int i = 0; i < pixelGridSizeX; i++) {
      // Grid column
      for (int j = 0; j < pixelGridSizeY; j++) {
        // Grid row

        // Calculate the center of the current pixel cell
        final double cellCenterX = (i + 0.5) * pixelWidth;
        final double cellCenterY = (j + 0.5) * pixelHeight;
        final cellCenter = Offset(cellCenterX, cellCenterY);

        // Check if the cell center is inside the animated flame path
        if (path.contains(cellCenter)) {
          // Define the rectangle for the pixel
          final Rect pixelRect = Rect.fromLTWH(
            i * pixelWidth,
            j * pixelHeight,
            pixelWidth, // Use calculated pixel width
            pixelHeight, // Use calculated pixel height
          );

          // Determine if it's an "inner" pixel for the brighter core
          bool isInner = j > pixelGridSizeY * 0.6 && // Lower part
              (i > pixelGridSizeX * 0.25 && i < pixelGridSizeX * 0.75); // Central horizontally

          // Add flickering chance to inner pixels
          // Make flicker more pronounced based on animation value peaks
          double flickerChance = 0.4 + (math.sin(time * 2) * 0.2); // Base chance + time variance
          if (isInner && random.nextDouble() > flickerChance) {
            canvas.drawRect(pixelRect, innerFlamePaint);
          } else {
            canvas.drawRect(pixelRect, outerFlamePaint);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant AnimatedPixelFlamePainter oldDelegate) {
    // Only repaint if the animation value itself has changed.
    return animation.value != oldDelegate.animation.value;
  }
}
