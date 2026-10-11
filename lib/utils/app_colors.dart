import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF0A0E1F);
  static const backgroundAlt = Color(0xFF131A38);
  static const surface = Color(0xFF1B2347);
  static const surfaceHigh = Color(0xFF262F5C);
  static const outline = Color(0xFF39437A);

  static const human = Color(0xFF2DD4BF);
  static const ai = Color(0xFFA78BFA);
  static const correct = Color(0xFF34D399);
  static const wrong = Color(0xFFFB7185);
  static const combo = Color(0xFFFBBF24);
  static const heart = Color(0xFFFF5C8A);

  static const textMuted = Color(0xFF9AA4D4);

  static const backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [background, backgroundAlt],
  );
}
