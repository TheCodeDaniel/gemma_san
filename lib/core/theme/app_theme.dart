import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Palette ────────────────────────────────────────────────────────────────

class AppColors {
  AppColors._();

  static const terracotta = Color(0xFFC9572C);
  static const deepGreen  = Color(0xFF2C5F4A);
  static const sunYellow  = Color(0xFFF5C842);
  static const warmCream  = Color(0xFFFBF6EC);
  static const charcoal   = Color(0xFF2A2522);

  // Lighter / surface variants
  static const terracottaLight = Color(0xFFF4CBB8);
  static const deepGreenLight  = Color(0xFFB8D8CC);
  static const warmCreamDark   = Color(0xFFEDE6D6);

  // Mode indicator colours
  static const socratic = Color(0xFF2C5F4A);  // green
  static const direct   = Color(0xFF3D5A80);  // slate blue
  static const encourage = Color(0xFFE76F51); // warm orange-red
}

// ── Spacing / radii ────────────────────────────────────────────────────────

class AppSpacing {
  AppSpacing._();

  static const double xs  = 4;
  static const double sm  = 8;
  static const double md  = 16;
  static const double lg  = 24;
  static const double xl  = 32;
  static const double xxl = 48;

  static const double cardRadius   = 20;
  static const double buttonRadius = 32; // pill
  static const double minTap       = 56;
}

// ── Text styles ────────────────────────────────────────────────────────────

class AppText {
  AppText._();

  static TextStyle display({Color color = AppColors.charcoal}) =>
      GoogleFonts.quicksand(fontSize: 32, fontWeight: FontWeight.w700, color: color, height: 1.15);

  static TextStyle heading({Color color = AppColors.charcoal}) =>
      GoogleFonts.quicksand(fontSize: 24, fontWeight: FontWeight.w700, color: color, height: 1.25);

  static TextStyle title({Color color = AppColors.charcoal}) =>
      GoogleFonts.quicksand(fontSize: 20, fontWeight: FontWeight.w700, color: color, height: 1.3);

  static TextStyle button({Color color = Colors.white}) =>
      GoogleFonts.quicksand(fontSize: 20, fontWeight: FontWeight.w700, color: color, height: 1.2);

  static TextStyle body({Color color = AppColors.charcoal}) =>
      GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w400, color: color, height: 1.5);

  static TextStyle bodyBold({Color color = AppColors.charcoal}) =>
      GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: color, height: 1.5);

  static TextStyle caption({Color color = AppColors.charcoal}) =>
      GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400,
          color: color.withValues(alpha: 0.65), height: 1.4);

  static TextStyle label({Color color = AppColors.charcoal}) =>
      GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, color: color, height: 1.4);
}

// ── Shadows ────────────────────────────────────────────────────────────────

class AppShadows {
  AppShadows._();

  static List<BoxShadow> card = [
    BoxShadow(color: AppColors.charcoal.withValues(alpha: 0.10), blurRadius: 8, offset: const Offset(0, 3)),
  ];

  static List<BoxShadow> button(Color color) => [
    BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 5)),
  ];

  static List<BoxShadow> floating = [
    BoxShadow(color: AppColors.charcoal.withValues(alpha: 0.18), blurRadius: 20, offset: const Offset(0, 8)),
  ];
}

// ── MaterialApp theme ──────────────────────────────────────────────────────

ThemeData buildAppTheme() => ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.terracotta,
    surface: AppColors.warmCream,
    primary: AppColors.terracotta,
    secondary: AppColors.deepGreen,
  ),
  scaffoldBackgroundColor: AppColors.warmCream,
  useMaterial3: true,
  textTheme: GoogleFonts.interTextTheme(),
  appBarTheme: AppBarTheme(
    backgroundColor: AppColors.warmCream,
    elevation: 0,
    titleTextStyle: AppText.heading(),
    iconTheme: const IconThemeData(color: AppColors.charcoal),
  ),
);
