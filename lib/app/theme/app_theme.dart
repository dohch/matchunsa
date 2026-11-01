import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Custom page transition: subtle fade + slide, iOS-like.
class MuPageTransition<T> extends PageRouteBuilder<T> {
  MuPageTransition({required this.page, super.settings})
      : super(
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 260),
          pageBuilder: (_, __, ___) => page,
          transitionsBuilder: (context, animation, secondary, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.03, 0),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        );

  final Widget page;
}

/// MatchUNSA visual system: Apple-inspired clarity with UNSA institutional colors.
abstract final class AppTheme {
  static const Color maroon = Color(0xFF5E151D);
  static const Color navy = Color(0xFF141E42);
  static const Color gray = Color(0xFF999999);

  static const Color canvas = Color(0xFFF5F6F8);
  static const Color canvasSoft = Color(0xFFFAFAFB);
  static const Color surface = Colors.white;
  static const Color hairline = Color(0xFFE8E9ED);
  static const Color ink = Color(0xFF1C1C1E);
  static const Color inkSecondary = Color(0xFF636366);
  static const Color inkTertiary = Color(0xFF8E8E93);

  static const double radiusSm = 12;
  static const double radiusMd = 18;
  static const double radiusLg = 24;
  static const double radiusXl = 28;

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: navy.withValues(alpha: 0.06),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: navy.withValues(alpha: 0.03),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: navy.withValues(alpha: 0.05),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ];

  static LinearGradient get brandGradient => const LinearGradient(
        colors: [maroon, Color(0xFF3D0E14)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get heroGradient => const LinearGradient(
        colors: [navy, Color(0xFF1A274F), maroon],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static String? get _platformDisplayFont {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return '.SF Pro Display';
      default:
        return null;
    }
  }

  static String? get _platformTextFont {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return '.SF Pro Text';
      default:
        return null;
    }
  }

  static TextStyle _display(TextStyle base) {
    final platform = _platformDisplayFont;
    if (platform != null) return base.copyWith(fontFamily: platform);
    return GoogleFonts.inter(textStyle: base);
  }

  static TextStyle _text(TextStyle base) {
    final platform = _platformTextFont;
    if (platform != null) return base.copyWith(fontFamily: platform);
    return GoogleFonts.inter(textStyle: base);
  }

  static TextTheme _textTheme() {
    final base = TextTheme(
      displayLarge: _display(const TextStyle(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.2,
        height: 1.1,
        color: navy,
      )),
      displayMedium: _display(const TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        height: 1.15,
        color: navy,
      )),
      headlineLarge: _display(const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        height: 1.2,
        color: navy,
      )),
      headlineMedium: _display(const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.25,
        color: navy,
      )),
      headlineSmall: _display(const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        height: 1.3,
        color: navy,
      )),
      titleLarge: _text(const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.3,
        color: navy,
      )),
      titleMedium: _text(const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        height: 1.35,
        color: navy,
      )),
      titleSmall: _text(const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: navy,
      )),
      bodyLarge: _text(const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: inkSecondary,
      )),
      bodyMedium: _text(const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: inkSecondary,
      )),
      bodySmall: _text(const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: inkTertiary,
      )),
      labelLarge: _text(const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: navy,
      )),
      labelMedium: _text(const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: navy,
      )),
      labelSmall: _text(const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: inkTertiary,
      )),
    );
    return base;
  }

  static final ColorScheme _colorScheme = ColorScheme.fromSeed(
    seedColor: maroon,
    brightness: Brightness.light,
    primary: maroon,
    secondary: navy,
    tertiary: gray,
    surface: surface,
    error: const Color(0xFFB3261E),
  );

  static final ThemeData light = ThemeData(
    useMaterial3: true,
    colorScheme: _colorScheme,
    scaffoldBackgroundColor: canvas,
    textTheme: _textTheme(),
    primaryTextTheme: _textTheme(),
    appBarTheme: AppBarTheme(
      backgroundColor: surface.withValues(alpha: 0.92),
      foregroundColor: navy,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: _display(const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: navy,
        letterSpacing: -0.3,
      )),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shadowColor: navy.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLg),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: navy.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusXl),
      ),
      titleTextStyle: _display(const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: navy,
      )),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF2F3F5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: _text(const TextStyle(color: inkTertiary, fontSize: 15)),
      labelStyle: _text(const TextStyle(color: inkSecondary, fontSize: 14)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: maroon, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: Color(0xFFB3261E)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: Color(0xFFB3261E), width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: maroon,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        textStyle: _text(const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
          letterSpacing: -0.2,
        )),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: maroon,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: navy,
        side: const BorderSide(color: hairline),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        textStyle: _text(const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        )),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: maroon,
        textStyle: _text(const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        )),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFFF2E8E9),
      selectedColor: maroon.withValues(alpha: 0.12),
      disabledColor: canvas,
      labelStyle: _text(const TextStyle(
        color: navy,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      )),
      secondaryLabelStyle: _text(const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      )),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusSm),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface.withValues(alpha: 0.94),
      elevation: 0,
      height: 68,
      indicatorColor: maroon.withValues(alpha: 0.12),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => _text(TextStyle(
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? maroon : inkTertiary,
        )),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 24,
          color: states.contains(WidgetState.selected) ? maroon : inkSecondary,
        ),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: maroon,
      unselectedLabelColor: inkTertiary,
      indicatorColor: maroon,
      indicatorSize: TabBarIndicatorSize.label,
      labelStyle: _text(const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 13,
      )),
      unselectedLabelStyle: _text(const TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 13,
      )),
      dividerColor: hairline,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: maroon,
      circularTrackColor: Color(0xFFEDEDEF),
      linearTrackColor: Color(0xFFEDEDEF),
    ),
    dividerTheme: const DividerThemeData(
      color: hairline,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: navy,
      contentTextStyle: _text(const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w500,
      )),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMd),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return maroon;
        return Colors.white;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return maroon.withValues(alpha: 0.35);
        }
        return const Color(0xFFE5E5EA);
      }),
    ),
    iconTheme: const IconThemeData(color: navy, size: 22),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: maroon,
      foregroundColor: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMd),
      ),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMd),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      iconColor: navy,
      titleTextStyle: _text(const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: navy,
        height: 1.3,
      )),
      subtitleTextStyle: _text(const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: inkSecondary,
        height: 1.35,
      )),
    ),
    badgeTheme: BadgeThemeData(
      backgroundColor: maroon,
      textColor: Colors.white,
      smallSize: 8,
      largeSize: 18,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 10,
      shadowColor: navy.withValues(alpha: 0.14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMd),
      ),
      textStyle: _text(const TextStyle(fontSize: 14, color: navy)),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
      ),
    ),
    searchBarTheme: SearchBarThemeData(
      backgroundColor: const WidgetStatePropertyAll(Color(0xFFF2F3F5)),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      elevation: const WidgetStatePropertyAll(0),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
      ),
      hintStyle: WidgetStatePropertyAll(
        _text(const TextStyle(color: inkTertiary, fontSize: 14)),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: maroon,
      thumbColor: maroon,
      inactiveTrackColor: maroon.withValues(alpha: 0.15),
      trackHeight: 4,
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
    ),
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        TargetPlatform.fuchsia: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
  );
}
