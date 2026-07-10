import 'package:flutter/material.dart';

abstract final class AppTypography {
  static TextTheme textTheme(Color primaryText, Color secondaryText) {
    return TextTheme(
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: primaryText,
        height: 1.2,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: primaryText,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: primaryText,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        color: primaryText,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: secondaryText,
        height: 1.45,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: primaryText,
      ),
    );
  }
}
