import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color neonOrange = Color(0xFFFF5F1F);
  static const Color neonGreen = Color(0xFF39FF14);
  static const Color darkGreen = Color(0xFF1A2F25);
  static const Color cardBackground = Color(0xFFF3E8FF);
  static const Color grayUnselected = Color(0xFF9CA3AF);
  static const Color grayText = Colors.black54;

  // Trail Tier Colors (Premium Palette)
  static const Color emeraldGR = Color(0xFF064E3B); // Deep Emerald for Top Tier
  static const Color forestRegional = Color(0xFF059669); // More saturated Forest
  static const Color sageLocal = Color(0xFF9CA3AF); // Standard Gray for Local
  static const Color selectionGlow = Color(0xFFFF8A5C); // Warmer glow for selection

  // Text Styles
  static TextStyle get titleStyle => GoogleFonts.nunito(
        fontWeight: FontWeight.bold,
        color: darkGreen,
      );

  static TextStyle get subtitleStyle => const TextStyle(
        color: Colors.black87,
        fontSize: 13,
      );

  static TextStyle get distanceStyle => const TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.black54,
        fontSize: 14,
      );

  // Button Styles
  static ButtonStyle get primaryButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: neonOrange,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );

  static ButtonStyle get startButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: neonGreen,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );

  static ButtonStyle get secondaryButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );
}
