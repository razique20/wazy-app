import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ──────────────────────────────────────────────────────────────────────────────
// FinavigColors — the single source of truth for every color in the app.
//
// Modern bento palette: a calm indigo accent, ink hero backdrops, a soft
// off-white canvas in light mode and deep desaturated surfaces in dark mode.
// Legacy names (navyPrimary, cyanSecondary, …) are kept as aliases so every
// existing call site picks up the new look automatically.
// ──────────────────────────────────────────────────────────────────────────────

class FinavigColors {
  FinavigColors._();

  // ── Brand accents ───────────────────────────────────────────────────────
  static const Color accent = Color(0xFF4F46E5); // indigo-600
  static const Color accentDeep = Color(0xFF4338CA); // indigo-700
  static const Color accentBright = Color(0xFF818CF8); // indigo-400
  static const Color accentSoft = Color(0xFFEEF2FF); // indigo-50

  // Legacy aliases — map old names onto the new accent so the whole app
  // modernizes without touching every call site.
  static const Color navyPrimary = accent;
  static const Color navyPrimaryDark = accentDeep;
  static const Color cyanSecondary = accentBright;
  static const Color cyan = accentBright;
  static const Color cyanDark = accent;
  static const Color violet = accent;
  static const Color violetDark = accentDeep;
  static const Color cyanAccent = accentBright;
  static const Color violetAccent = accent;
  static const Color emerald = Color(0xFF10B981);
  static const Color emeraldAccent = emerald;
  static const Color textPrimaryDark = textPrimary;

  // ── Ink (hero backdrops, dark CTAs) ─────────────────────────────────────
  static const Color ink = Color(0xFF0F172A);
  static const Color inkDeep = Color(0xFF0B1120);

  // ── Surfaces — Dark mode ────────────────────────────────────────────────
  static const Color obsidian = Color(0xFF0C0E14);
  static const Color charcoal = Color(0xFF151824);
  static const Color slate = Color(0xFF1D2130);
  static const Color slateLight = Color(0xFF2B3042);

  // ── Surfaces — Light mode ───────────────────────────────────────────────
  static const Color snowWhite = Color(0xFFF7F8FA); // canvas
  static const Color cloud = Color(0xFFF2F3F7); // tiles on white sheets
  static const Color mist = Color(0xFFE9EBF1); // subtle fills
  static const Color fog = Color(0xFFDFE3EC); // hairlines

  // ── Bento tile tints (accent + matching pastel container) ───────────────
  static const Color indigo = Color(0xFF4F46E5);
  static const Color indigoTint = Color(0xFFEEF2FF);
  static const Color blue = Color(0xFF3B82F6);
  static const Color blueTint = Color(0xFFDBEAFE);
  static const Color sky = Color(0xFF0EA5E9);
  static const Color skyTint = Color(0xFFE0F2FE);
  static const Color teal = Color(0xFF14B8A6);
  static const Color tealTint = Color(0xFFCCFBF1);
  static const Color green = Color(0xFF22C55E);
  static const Color greenTint = Color(0xFFDCFCE7);
  static const Color amber = Color(0xFFF59E0B);
  static const Color amberTint = Color(0xFFFEF3C7);
  static const Color orange = Color(0xFFF97316);
  static const Color orangeTint = Color(0xFFFFEDD5);
  static const Color red = Color(0xFFEF4444);
  static const Color redTint = Color(0xFFFEE2E2);
  static const Color pink = Color(0xFFEC4899);
  static const Color pinkTint = Color(0xFFFCE7F3);
  static const Color lilac = Color(0xFF8B5CF6);
  static const Color lilacTint = Color(0xFFEDE9FE);

  // ── Semantic: urgency ───────────────────────────────────────────────────
  static const Color safe = Color(0xFF10B981);
  static const Color safeBg = Color(0xFF052E1F);
  static const Color safeBgLight = Color(0xFFECFDF5);

  static const Color caution = Color(0xFFFBBF24);
  static const Color cautionBg = Color(0xFF3A2A03);
  static const Color cautionBgLight = Color(0xFFFFFBEB);

  static const Color warning = Color(0xFFF59E0B);
  static const Color warningBg = Color(0xFF3B2503);
  static const Color warningBgLight = Color(0xFFFFF7ED);

  static const Color danger = Color(0xFFEF4444);
  static const Color dangerDark = Color(0xFFDC2626);
  static const Color dangerBg = Color(0xFF450A0A);
  static const Color dangerBgLight = Color(0xFFFEF2F2);

  // ── Text ────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF2F4F8);
  static const Color textSecondary = Color(0xFF9AA3B5);
  static const Color textMuted = Color(0xFF6C7688);

  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF5B6472);
  static const Color textMutedLight = Color(0xFF8A93A6);

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
// FinavigRadius — the corner-radius scale. Everything sits on a 16–28px grid.
// ──────────────────────────────────────────────────────────────────────────────

class FinavigRadius {
  FinavigRadius._();

  static const double card = 20;
  static const double tile = 16;
  static const double field = 14;
  static const double button = 16;
  static const double sheet = 28;
  static const double dialog = 24;
}

// ──────────────────────────────────────────────────────────────────────────────
// FinavigShadows — soft, diffuse elevation. Light mode lifts cards with a whisper
// shadow; dark mode relies on hairline borders instead (shadow-on-dark reads
// as noise).
// ──────────────────────────────────────────────────────────────────────────────

class FinavigShadows {
  FinavigShadows._();

  static const List<BoxShadow> soft = [
    BoxShadow(
      color: Color(0x12101828),
      blurRadius: 20,
      offset: Offset(0, 6),
    ),
  ];

  static const List<BoxShadow> raised = [
    BoxShadow(
      color: Color(0x1F101828),
      blurRadius: 28,
      offset: Offset(0, 10),
    ),
  ];

  static const List<BoxShadow> none = [];

  static List<BoxShadow> adaptive(bool isDark) => isDark ? none : soft;
}

// ──────────────────────────────────────────────────────────────────────────────
// FinavigGradients — reusable gradient definitions.
// ──────────────────────────────────────────────────────────────────────────────

class FinavigGradients {
  FinavigGradients._();

  static const LinearGradient primary = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryAccent = primary;
  static const LinearGradient darkHeader = splash;

  static const LinearGradient surfaceDark = LinearGradient(
    colors: [FinavigColors.obsidian, FinavigColors.charcoal],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient surfaceLight = LinearGradient(
    colors: [FinavigColors.snowWhite, FinavigColors.cloud],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient splash = LinearGradient(
    colors: [Color(0xFF0B1120), Color(0xFF151830), Color(0xFF1E1B4B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient splashLight = LinearGradient(
    colors: [Color(0xFFF5F6FB), Color(0xFFEEF0FA), Color(0xFFF7F8FA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ──────────────────────────────────────────────────────────────────────────────
// FinavigGlass — a helper widget for frosted glass containers.
// ──────────────────────────────────────────────────────────────────────────────

class FinavigGlass extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final double opacity;
  final double blur;
  final Color? borderColor;

  const FinavigGlass({
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
        : Colors.white.withOpacity(0.72);
    final border = borderColor ??
        (isDark ? FinavigColors.glassBorderWhite : FinavigColors.glassBorderBlack);

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
// FinavigTheme — full ThemeData builders.
// ──────────────────────────────────────────────────────────────────────────────

class FinavigTheme {
  FinavigTheme._();

  // google_fonts hardcodes `fontFamilyFallback: ['Inter']` on
  // every style it returns, which blocks the engine's automatic fallback to
  // the platform emoji font — emoji then render as tofu ("?") on iOS. Append
  // the platform emoji fonts explicitly so emoji always resolve.
  static const List<String> _emojiFallback = [
    'Apple Color Emoji', // iOS, macOS
    'Segoe UI Emoji', // Windows
    'Noto Color Emoji', // Android, Linux
  ];

  static TextStyle _withEmojiFallback(TextStyle style) =>
      style.copyWith(fontFamilyFallback: _emojiFallback);

  // ── Typography ──────────────────────────────────────────────────────────
  //
  // Inter: a neutral, professional UI sans — crisp and compact, the default
  // choice of modern fintech apps. Sizes match the original scale so nothing
  // feels oversized.

  static TextTheme _textTheme(Brightness brightness) {
    final base = brightness == Brightness.dark
        ? Typography.material2021().white
        : Typography.material2021().black;

    return GoogleFonts.interTextTheme(base).copyWith(
      displayLarge: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
      ),
      displaySmall: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      headlineLarge: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 17.5,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 15.5,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 13.5,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 12.5,
        fontWeight: FontWeight.w400,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w500,
      ),
    ).apply(fontFamilyFallback: _emojiFallback);
  }

  // ── Dark Theme ──────────────────────────────────────────────────────────

  static ThemeData dark() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: FinavigColors.accentBright,
      onPrimary: Color(0xFF101223),
      primaryContainer: Color(0xFF312E81),
      onPrimaryContainer: Color(0xFFE0E7FF),
      secondary: Color(0xFFA5B4FC),
      onSecondary: Color(0xFF101223),
      secondaryContainer: Color(0xFF2E2A5C),
      onSecondaryContainer: Color(0xFFC7D2FE),
      tertiary: Color(0xFF34D399),
      onTertiary: Color(0xFF052E1F),
      tertiaryContainer: Color(0xFF064E3B),
      onTertiaryContainer: Color(0xFFA7F3D0),
      error: Color(0xFFF87171),
      onError: Color(0xFF450A0A),
      errorContainer: Color(0xFF7F1D1D),
      onErrorContainer: Color(0xFFFECACA),
      surface: FinavigColors.obsidian,
      onSurface: FinavigColors.textPrimary,
      surfaceContainerHighest: FinavigColors.slate,
      outline: Color(0xFF6B7280),
      outlineVariant: FinavigColors.slateLight,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: FinavigColors.snowWhite,
      onInverseSurface: FinavigColors.obsidian,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      textTheme: _textTheme(Brightness.dark),
      scaffoldBackgroundColor: FinavigColors.obsidian,
      canvasColor: FinavigColors.charcoal,
      cardColor: FinavigColors.charcoal,
      dividerColor: Colors.white.withOpacity(0.06),
      splashColor: Colors.white.withOpacity(0.06),
      highlightColor: Colors.white.withOpacity(0.04),
      appBarTheme: AppBarTheme(
        backgroundColor: FinavigColors.obsidian,
        foregroundColor: FinavigColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: _withEmojiFallback(GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: FinavigColors.textPrimary,
          letterSpacing: -0.4,
        )),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: FinavigColors.obsidian.withOpacity(0.85),
        indicatorColor: FinavigColors.accentBright.withOpacity(0.16),
        labelTextStyle: WidgetStatePropertyAll(
          _withEmojiFallback(GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
          )),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: FinavigColors.accentBright, size: 22);
          }
          return const IconThemeData(color: FinavigColors.textMuted, size: 22);
        }),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: FinavigColors.charcoal,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FinavigRadius.card),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: FinavigColors.textSecondary,
        titleTextStyle: _withEmojiFallback(GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: FinavigColors.textPrimary,
        )),
        subtitleTextStyle: _withEmojiFallback(GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: FinavigColors.textSecondary,
        )),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: FinavigColors.slate.withOpacity(0.55),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FinavigRadius.field),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FinavigRadius.field),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FinavigRadius.field),
          borderSide: const BorderSide(color: FinavigColors.accentBright, width: 1.5),
        ),
        labelStyle: const TextStyle(color: FinavigColors.textSecondary, fontSize: 13),
        hintStyle: const TextStyle(color: FinavigColors.textMuted, fontSize: 13),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FinavigRadius.button),
          ),
          textStyle: _withEmojiFallback(GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          )),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: FinavigColors.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FinavigRadius.button),
          ),
          textStyle: _withEmojiFallback(GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          )),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.secondary,
          textStyle: _withEmojiFallback(GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          )),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FinavigRadius.card),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: FinavigColors.charcoal,
        modalBackgroundColor: FinavigColors.charcoal,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(FinavigRadius.sheet)),
        ),
        dragHandleColor: Colors.white.withOpacity(0.2),
        dragHandleSize: const Size(40, 4),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: FinavigColors.slate,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FinavigRadius.dialog),
        ),
        elevation: 0,
        titleTextStyle: _withEmojiFallback(GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: FinavigColors.textPrimary,
        )),
        contentTextStyle: _withEmojiFallback(GoogleFonts.inter(
          fontSize: 13.5,
          height: 1.5,
          color: FinavigColors.textSecondary,
        )),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: FinavigColors.slateLight,
        contentTextStyle:
            _withEmojiFallback(GoogleFonts.inter(
          color: FinavigColors.textPrimary,
          fontSize: 13,
        )),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: FinavigColors.slate,
        selectedColor: FinavigColors.accentBright.withOpacity(0.18),
        checkmarkColor: scheme.secondary,
        labelStyle: _withEmojiFallback(
            GoogleFonts.inter(fontSize: 12, color: FinavigColors.textPrimary, fontWeight: FontWeight.w500)),
        secondaryLabelStyle: _withEmojiFallback(GoogleFonts.inter(
            fontSize: 12, color: scheme.secondary, fontWeight: FontWeight.w600)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        side: BorderSide(color: Colors.white.withOpacity(0.06)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: FinavigColors.accentBright,
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
      primary: FinavigColors.accent,
      onPrimary: Colors.white,
      primaryContainer: FinavigColors.accentSoft,
      onPrimaryContainer: Color(0xFF312E81),
      secondary: Color(0xFF6366F1),
      onSecondary: Colors.white,
      secondaryContainer: FinavigColors.accentSoft,
      onSecondaryContainer: Color(0xFF3730A3),
      tertiary: Color(0xFF0D9488),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFCCFBF1),
      onTertiaryContainer: Color(0xFF134E4A),
      error: FinavigColors.dangerDark,
      onError: Colors.white,
      errorContainer: FinavigColors.dangerBgLight,
      onErrorContainer: Color(0xFF7F1D1D),
      surface: Colors.white,
      onSurface: FinavigColors.textPrimaryLight,
      onSurfaceVariant: FinavigColors.textSecondaryLight,
      surfaceContainerHighest: FinavigColors.cloud,
      outline: Color(0xFF667085),
      outlineVariant: Color(0xFFE5E8EF),
      shadow: Color(0x1A000000),
      scrim: Colors.black,
      inverseSurface: FinavigColors.charcoal,
      onInverseSurface: FinavigColors.snowWhite,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      textTheme: _textTheme(Brightness.light),
      scaffoldBackgroundColor: FinavigColors.snowWhite,
      canvasColor: Colors.white,
      cardColor: Colors.white,
      dividerColor: FinavigColors.mist,
      splashColor: scheme.primary.withOpacity(0.05),
      highlightColor: scheme.primary.withOpacity(0.03),
      appBarTheme: AppBarTheme(
        backgroundColor: FinavigColors.snowWhite,
        foregroundColor: FinavigColors.textPrimaryLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: _withEmojiFallback(GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: FinavigColors.textPrimaryLight,
          letterSpacing: -0.4,
        )),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white.withOpacity(0.92),
        indicatorColor: FinavigColors.accentSoft,
        labelTextStyle: WidgetStatePropertyAll(
          _withEmojiFallback(GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
          )),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: scheme.primary, size: 22);
          }
          return const IconThemeData(color: FinavigColors.textMutedLight, size: 22);
        }),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FinavigRadius.card),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: FinavigColors.textSecondaryLight,
        titleTextStyle: _withEmojiFallback(GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: FinavigColors.textPrimaryLight,
        )),
        subtitleTextStyle: _withEmojiFallback(GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: FinavigColors.textSecondaryLight,
        )),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: FinavigColors.cloud,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FinavigRadius.field),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FinavigRadius.field),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FinavigRadius.field),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        labelStyle: const TextStyle(color: FinavigColors.textSecondaryLight, fontSize: 13),
        hintStyle: const TextStyle(color: FinavigColors.textMutedLight, fontSize: 13),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FinavigRadius.button),
          ),
          textStyle: _withEmojiFallback(GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          )),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: FinavigColors.ink,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FinavigRadius.button),
          ),
          textStyle: _withEmojiFallback(GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          )),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: _withEmojiFallback(GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          )),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: FinavigColors.ink,
        foregroundColor: Colors.white,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FinavigRadius.card),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        modalBackgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(FinavigRadius.sheet)),
        ),
        dragHandleColor: Color(0xFFE2E5EC),
        dragHandleSize: Size(40, 4),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FinavigRadius.dialog),
        ),
        elevation: 0,
        titleTextStyle: _withEmojiFallback(GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: FinavigColors.textPrimaryLight,
        )),
        contentTextStyle: _withEmojiFallback(GoogleFonts.inter(
          fontSize: 13.5,
          height: 1.5,
          color: FinavigColors.textSecondaryLight,
        )),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: FinavigColors.ink,
        contentTextStyle:
            _withEmojiFallback(GoogleFonts.inter(
          color: Colors.white,
          fontSize: 13,
        )),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: FinavigColors.cloud,
        selectedColor: FinavigColors.accentSoft,
        checkmarkColor: scheme.primary,
        labelStyle: _withEmojiFallback(GoogleFonts.inter(
            fontSize: 12, color: FinavigColors.textPrimaryLight, fontWeight: FontWeight.w500)),
        secondaryLabelStyle: _withEmojiFallback(GoogleFonts.inter(
            fontSize: 12, color: scheme.primary, fontWeight: FontWeight.w600)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        side: const BorderSide(color: Color(0xFFEAECF2)),
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
