import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ──────────────────────────────────────────────────────────────────────────────
// WazyColors — the single source of truth for every color in the app.
// ──────────────────────────────────────────────────────────────────────────────

class WazyColors {
  WazyColors._();

  // ── Brand accents ───────────────────────────────────────────────────────
  static const Color navyPrimary = Color(0xFF23236B);
  static const Color navyPrimaryDark = Color(0xFF1E1B4B);
  static const Color cyanSecondary = Color(0xFF00E5FF);

  static const Color cyan = Color(0xFF00E5FF);
  static const Color cyanDark = Color(0xFF00B8D4);
  static const Color violet = Color(0xFF23236B);
  static const Color violetDark = Color(0xFF1E1B4B);
  static const Color emerald = Color(0xFF00E676);

  static const Color cyanAccent = cyanSecondary;
  static const Color violetAccent = navyPrimary;
  static const Color emeraldAccent = emerald;
  static const Color textPrimaryDark = textPrimary;

  // ── Surfaces — Dark mode ────────────────────────────────────────────────
  static const Color obsidian = Color(0xFF0A0E1A);
  static const Color charcoal = Color(0xFF111827);
  static const Color slate = Color(0xFF1E293B);
  static const Color slateLight = Color(0xFF334155);

  // ── Surfaces — Light mode ───────────────────────────────────────────────
  static const Color snowWhite = Color(0xFFF8FAFC);
  static const Color cloud = Color(0xFFF1F5F9);
  static const Color mist = Color(0xFFE2E8F0);
  static const Color fog = Color(0xFFCBD5E1);

  // ── Semantic: urgency ───────────────────────────────────────────────────
  static const Color safe = Color(0xFF10B981);
  static const Color safeBg = Color(0xFF064E3B);
  static const Color safeBgLight = Color(0xFFECFDF5);

  static const Color caution = Color(0xFFFFD740);
  static const Color cautionBg = Color(0xFF332B00);
  static const Color cautionBgLight = Color(0xFFFFF8E1);

  static const Color warning = Color(0xFFFF9100);
  static const Color warningBg = Color(0xFF331D00);
  static const Color warningBgLight = Color(0xFFFFF3E0);

  static const Color danger = Color(0xFFFF5252);
  static const Color dangerDark = Color(0xFFD32F2F);
  static const Color dangerBg = Color(0xFF330A0A);
  static const Color dangerBgLight = Color(0xFFFFEBEE);

  // ── Text ────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF475569);
  static const Color textMutedLight = Color(0xFF94A3B8);

  // ── Glass ───────────────────────────────────────────────────────────────
  static const Color glassWhite = Color(0x14FFFFFF); // 8%
  static const Color glassBorderWhite = Color(0x1FFFFFFF); // 12%
  static const Color glassBlack = Color(0x14000000);
  static const Color glassBorderBlack = Color(0x1F000000);

  // ── Helpers: urgency from days ──────────────────────────────────────────

  static Color urgencyColor(int days, {bool isActive = true}) {
    if (!isActive) return textMuted;
    if (days <= 7) return danger;
    if (days <= 30) return warning;
    if (days <= 60) return caution;
    return safe;
  }

  static Color urgencyBg(int days, {required Brightness brightness}) {
    if (brightness == Brightness.dark) {
      if (days <= 7) return dangerBg;
      if (days <= 30) return warningBg;
      if (days <= 60) return cautionBg;
      return safeBg;
    }
    if (days <= 7) return dangerBgLight;
    if (days <= 30) return warningBgLight;
    if (days <= 60) return cautionBgLight;
    return safeBgLight;
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// WazyGradients — reusable gradient definitions.
// ──────────────────────────────────────────────────────────────────────────────

class WazyGradients {
  WazyGradients._();

  static const LinearGradient primary = LinearGradient(
    colors: [WazyColors.cyan, WazyColors.violet],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryAccent = primary;
  static const LinearGradient darkHeader = splash;

  static const LinearGradient surfaceDark = LinearGradient(
    colors: [WazyColors.obsidian, WazyColors.charcoal],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient surfaceLight = LinearGradient(
    colors: [WazyColors.snowWhite, WazyColors.cloud],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient splash = LinearGradient(
    colors: [Color(0xFF0A0E1A), Color(0xFF0D1B2A), Color(0xFF1B2838)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient splashLight = LinearGradient(
    colors: [Color(0xFFF0F4FF), Color(0xFFE8EEFF), Color(0xFFF8FAFC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ──────────────────────────────────────────────────────────────────────────────
// WazyGlass — a helper widget for frosted glass containers.
// ──────────────────────────────────────────────────────────────────────────────

class WazyGlass extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final double opacity;
  final double blur;
  final Color? borderColor;

  const WazyGlass({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.padding,
    this.opacity = 0.08,
    this.blur = 12,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? Colors.white.withOpacity(opacity)
        : Colors.white.withOpacity(0.65);
    final border = borderColor ??
        (isDark ? WazyColors.glassBorderWhite : WazyColors.glassBorderBlack);

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: borderRadius,
            border: Border.all(color: border, width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// WazyTheme — full ThemeData builders.
// ──────────────────────────────────────────────────────────────────────────────

class WazyTheme {
  WazyTheme._();

  // ── Typography ──────────────────────────────────────────────────────────

  static TextTheme _textTheme(Brightness brightness) {
    final base = brightness == Brightness.dark
        ? Typography.material2021().white
        : Typography.material2021().black;

    return GoogleFonts.spaceGroteskTextTheme(base).copyWith(
      displayLarge: GoogleFonts.spaceGrotesk(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
      ),
      displayMedium: GoogleFonts.spaceGrotesk(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
      ),
      displaySmall: GoogleFonts.spaceGrotesk(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
      ),
      headlineLarge: GoogleFonts.spaceGrotesk(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      headlineMedium: GoogleFonts.spaceGrotesk(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
      headlineSmall: GoogleFonts.spaceGrotesk(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      titleLarge: GoogleFonts.spaceGrotesk(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      titleMedium: GoogleFonts.spaceGrotesk(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
      ),
      titleSmall: GoogleFonts.spaceGrotesk(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: GoogleFonts.spaceGrotesk(
        fontSize: 13.5,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: GoogleFonts.spaceGrotesk(
        fontSize: 12.5,
        fontWeight: FontWeight.w400,
      ),
      bodySmall: GoogleFonts.spaceGrotesk(
        fontSize: 11,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: GoogleFonts.spaceGrotesk(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: GoogleFonts.spaceGrotesk(
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: GoogleFonts.spaceGrotesk(
        fontSize: 10,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  // ── Dark Theme ──────────────────────────────────────────────────────────

  static ThemeData dark() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF23236B),
      onPrimary: Colors.white,
      primaryContainer: Color(0xFF1E1B4B),
      onPrimaryContainer: Colors.white,
      secondary: WazyColors.cyanSecondary,
      onSecondary: Color(0xFF0A0E1A),
      secondaryContainer: Color(0xFF004D5A),
      onSecondaryContainer: Color(0xFF80F4FF),
      tertiary: WazyColors.emerald,
      onTertiary: WazyColors.obsidian,
      tertiaryContainer: Color(0xFF003D1A),
      onTertiaryContainer: Color(0xFFA5F3C8),
      error: WazyColors.danger,
      onError: Colors.white,
      errorContainer: WazyColors.dangerBg,
      onErrorContainer: Color(0xFFFFB4AB),
      surface: WazyColors.obsidian,
      onSurface: WazyColors.textPrimary,
      surfaceContainerHighest: WazyColors.slate,
      outline: WazyColors.textMuted,
      outlineVariant: WazyColors.slateLight,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: WazyColors.cloud,
      onInverseSurface: WazyColors.charcoal,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      textTheme: _textTheme(Brightness.dark),
      scaffoldBackgroundColor: WazyColors.obsidian,
      canvasColor: WazyColors.charcoal,
      cardColor: WazyColors.charcoal,
      dividerColor: WazyColors.slateLight.withOpacity(0.3),
      appBarTheme: AppBarTheme(
        backgroundColor: WazyColors.obsidian,
        foregroundColor: WazyColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          fontSize: 17.5,
          fontWeight: FontWeight.w600,
          color: WazyColors.textPrimary,
          letterSpacing: -0.3,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: WazyColors.obsidian.withOpacity(0.85),
        indicatorColor: WazyColors.cyanSecondary.withOpacity(0.15),
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.spaceGrotesk(
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: WazyColors.cyanSecondary, size: 22);
          }
          return const IconThemeData(color: WazyColors.textMuted, size: 22);
        }),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: WazyColors.charcoal,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: WazyColors.glassBorderWhite),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: WazyColors.slate.withOpacity(0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: WazyColors.slateLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: WazyColors.slateLight.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: WazyColors.cyanSecondary, width: 1.5),
        ),
        labelStyle: const TextStyle(color: WazyColors.textSecondary, fontSize: 13),
        hintStyle: const TextStyle(color: WazyColors.textMuted, fontSize: 13),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF23236B),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: WazyColors.cyanSecondary,
          foregroundColor: const Color(0xFF0A0E1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: WazyColors.cyanSecondary,
          textStyle: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: WazyColors.cyanSecondary,
        foregroundColor: const Color(0xFF0A0E1A),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: WazyColors.charcoal,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: WazyColors.charcoal,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 8,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: WazyColors.slate,
        contentTextStyle: GoogleFonts.spaceGrotesk(
          color: WazyColors.textPrimary,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: WazyColors.slate,
        selectedColor: WazyColors.cyanSecondary.withOpacity(0.2),
        labelStyle: GoogleFonts.spaceGrotesk(fontSize: 11.5, color: WazyColors.textPrimary),
        secondaryLabelStyle: GoogleFonts.spaceGrotesk(fontSize: 11.5, color: WazyColors.cyanSecondary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: BorderSide(color: WazyColors.slateLight.withOpacity(0.3)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: WazyColors.cyanSecondary,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  // ── Light Theme ─────────────────────────────────────────────────────────

  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF23236B), // Deep Navy Primary from screenshot
      onPrimary: Colors.white,
      primaryContainer: Color(0xFF23236B),
      onPrimaryContainer: Colors.white,
      secondary: Color(0xFF00E5FF), // Light Cyan Secondary from screenshot
      onSecondary: Color(0xFF0A0E1A),
      secondaryContainer: Color(0xFFE0F7FA),
      onSecondaryContainer: Color(0xFF004D40),
      tertiary: Color(0xFF006D3B),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFA5F3C8),
      onTertiaryContainer: Color(0xFF002110),
      error: WazyColors.dangerDark,
      onError: Colors.white,
      errorContainer: WazyColors.dangerBgLight,
      onErrorContainer: Color(0xFF410E0E),
      surface: WazyColors.snowWhite,
      onSurface: WazyColors.textPrimaryLight,
      onSurfaceVariant: WazyColors.textSecondaryLight,
      surfaceContainerHighest: WazyColors.mist,
      outline: WazyColors.textMutedLight,
      outlineVariant: WazyColors.fog,
      shadow: Color(0x1A000000),
      scrim: Colors.black,
      inverseSurface: WazyColors.charcoal,
      onInverseSurface: WazyColors.cloud,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      textTheme: _textTheme(Brightness.light),
      scaffoldBackgroundColor: WazyColors.snowWhite,
      canvasColor: Colors.white,
      cardColor: Colors.white,
      dividerColor: WazyColors.fog,
      appBarTheme: AppBarTheme(
        backgroundColor: WazyColors.snowWhite,
        foregroundColor: WazyColors.textPrimaryLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          fontSize: 17.5,
          fontWeight: FontWeight.w600,
          color: WazyColors.textPrimaryLight,
          letterSpacing: -0.3,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white.withOpacity(0.92),
        indicatorColor: scheme.primary.withOpacity(0.1),
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.spaceGrotesk(
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: scheme.primary, size: 22);
          }
          return const IconThemeData(color: WazyColors.textMutedLight, size: 22);
        }),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: WazyColors.fog.withOpacity(0.5)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: WazyColors.cloud,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: WazyColors.fog),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: WazyColors.fog),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        labelStyle: const TextStyle(color: WazyColors.textSecondaryLight, fontSize: 13),
        hintStyle: const TextStyle(color: WazyColors.textMutedLight, fontSize: 13),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 8,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: WazyColors.charcoal,
        contentTextStyle: GoogleFonts.spaceGrotesk(
          color: WazyColors.textPrimary,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: WazyColors.cloud,
        selectedColor: scheme.primary.withOpacity(0.12),
        labelStyle: GoogleFonts.spaceGrotesk(fontSize: 11.5, color: WazyColors.textPrimaryLight),
        secondaryLabelStyle: GoogleFonts.spaceGrotesk(fontSize: 11.5, color: scheme.primary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: BorderSide(color: WazyColors.fog),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
