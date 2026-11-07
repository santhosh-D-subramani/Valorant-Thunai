import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppRadius {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 20;
  static const double xxl = 28;
  static const double xxxl = 32;

  static const BorderRadius brS = BorderRadius.all(Radius.circular(s));
  static const BorderRadius brM = BorderRadius.all(Radius.circular(m));
  static const BorderRadius brL = BorderRadius.all(Radius.circular(l));
  static const BorderRadius brXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius brXxl = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius brXxxl = BorderRadius.all(Radius.circular(xxxl));
}

ThemeData buildTheme({
  required Brightness brightness,
  required Color seedColor,
  required double blendLevel,
  required bool pureBlackDark,
}) {
  final baseScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.expressive,
  );

  final blendedBackground = Color.lerp(
    baseScheme.surface,
    seedColor,
    blendLevel * 0.15,
  )!;

  final surface = brightness == Brightness.dark && pureBlackDark
      ? Colors.black
      : blendedBackground;

  final scheme = baseScheme.copyWith(surface: surface);

  final navBackgroundColor = ElevationOverlay.applySurfaceTint(
    surface,
    scheme.surfaceTint,
    1,
  );

  final textTheme = _expressiveTextTheme(scheme);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: surface,
    textTheme: textTheme,

    progressIndicatorTheme: const ProgressIndicatorThemeData(),
    sliderTheme: const SliderThemeData(),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: navBackgroundColor,
      elevation: 0,
      indicatorShape: const StadiumBorder(),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => textTheme.labelMedium?.copyWith(
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: navBackgroundColor,
      indicatorShape: const StadiumBorder(),
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      surfaceTintColor: scheme.surfaceTint,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    ),

    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.brXl),
      margin: EdgeInsets.zero,
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: const StadiumBorder(),
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    segmentedButtonTheme: const SegmentedButtonThemeData(
      style: ButtonStyle(shape: WidgetStatePropertyAll(StadiumBorder())),
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.brL),
    ),

    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide(color: scheme.outlineVariant),
      labelStyle: textTheme.labelLarge,
    ),

    dialogTheme: const DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.brXxl),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xxl),
        ),
      ),
      showDragHandle: true,
    ),
    popupMenuTheme: const PopupMenuThemeData(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.brL),
    ),
    menuTheme: const MenuThemeData(
      style: MenuStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: AppRadius.brL),
        ),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.brM),
    ),
    tooltipTheme: const TooltipThemeData(
      decoration: BoxDecoration(borderRadius: AppRadius.brS),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      border: const OutlineInputBorder(
        borderRadius: AppRadius.brL,
        borderSide: BorderSide.none,
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: AppRadius.brL,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.brL,
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),

    listTileTheme: const ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.brL),
    ),

    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      space: 1,
      thickness: 1,
    ),
  );
}

TextTheme _expressiveTextTheme(ColorScheme scheme) {
  final base = ThemeData(brightness: scheme.brightness).textTheme;

  return base
      .copyWith(
        displayLarge: GoogleFonts.outfit(
          textStyle: base.displayLarge,
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
        ),
        displayMedium: GoogleFonts.outfit(
          textStyle: base.displayMedium,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        displaySmall: GoogleFonts.outfit(
          textStyle: base.displaySmall,
          fontWeight: FontWeight.w700,
        ),
        headlineLarge: GoogleFonts.outfit(
          textStyle: base.headlineLarge,
          fontWeight: FontWeight.w800,
        ),
        headlineMedium: GoogleFonts.outfit(
          textStyle: base.headlineMedium,
          fontWeight: FontWeight.w700,
        ),
        headlineSmall: GoogleFonts.outfit(
          textStyle: base.headlineSmall,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: GoogleFonts.outfit(
          textStyle: base.titleLarge,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: GoogleFonts.inter(
          textStyle: base.titleMedium,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: GoogleFonts.inter(
          textStyle: base.titleSmall,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: GoogleFonts.inter(textStyle: base.bodyLarge),
        bodyMedium: GoogleFonts.inter(textStyle: base.bodyMedium),
        bodySmall: GoogleFonts.inter(textStyle: base.bodySmall),
        labelLarge: GoogleFonts.inter(
          textStyle: base.labelLarge,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: GoogleFonts.inter(
          textStyle: base.labelMedium,
          fontWeight: FontWeight.w600,
        ),
        labelSmall: GoogleFonts.inter(
          textStyle: base.labelSmall,
          fontWeight: FontWeight.w600,
        ),
      )
      .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
}
