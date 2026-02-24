import 'package:flutter/material.dart';

// T012: Design system colour tokens.
// All colours are referenced from here — no inline Color() values elsewhere.

abstract final class AppColors {
  // Primary palette
  static const Color primary = Color(0xFF1A56DB);
  static const Color primaryVariant = Color(0xFF1240A8);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Surface palette
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFEFF3FB);
  static const Color onBackground = Color(0xFF1A1A2E);
  static const Color onSurface = Color(0xFF1A1A2E);
  static const Color onSurfaceVariant = Color(0xFF4A4A6A);

  // Status palette
  static const Color error = Color(0xFFD32F2F);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color warning = Color(0xFFF57C00);
  static const Color success = Color(0xFF388E3C);

  // Sync state badges
  static const Color syncPending = Color(0xFFF57C00);
  static const Color syncConflict = Color(0xFFD32F2F);
  static const Color syncSynced = Color(0xFF388E3C);
  static const Color syncOffline = Color(0xFF9E9E9E);

  // Annotation colours
  static const Color inkPen = Color(0xFF1A1A2E);
  static const Color inkHighlighter = Color(0xFFFFEB3B);

  // Divider and border
  static const Color divider = Color(0xFFE0E0E0);
  static const Color border = Color(0xFFCCCCDD);
}
