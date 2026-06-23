import 'package:flutter/material.dart';

const Color zMemcoOrange = Color(0xFFF97316);
const Color zMemcoOrangeDark = Color(0xFFEA580C);
const Color zMemcoBlack = Color(0xFF111111);
const Color zMemcoGraphite = Color(0xFF2B2F33);
const Color zMemcoDarkGray = Color(0xFF3F3F46);
const Color zMemcoCanvas = Color(0xFFF4F4F5);

const Color zTealTop = Color(0xFF2B2F33);
const Color zDarkBar = Color(0xFF111111);
const Color zIconRail = Color(0xFF18181B);
const Color zSidebarBg = Color(0xFFF5F5F4);
const Color zCanvasBg = Color(0xFFF4F4F5);
const Color zBorder = Color(0xFFE4E4E7);
const Color zText = Color(0xFF18181B);
const Color zMuted = Color(0xFF71717A);

const Color zBlue = Color(0xFFF97316);
const Color zBlueDark = Color(0xFFEA580C);
const Color zBlueDeep = Color(0xFFC2410C);
const Color zBlueSoft = Color(0xFFFFF7ED);

const Color zSuccess = Color(0xFF16A34A);
const Color zSuccessSoft = Color(0xFFDCFCE7);

const Color zOrange = Color(0xFFF97316);
const Color zOrangeSoft = Color(0xFFFFF7ED);

const Color zPurple = Color(0xFF7C3AED);
const Color zPurpleSoft = Color(0xFFF3E8FF);

const Color zDanger = Color(0xFFDC2626);
const Color zDangerSoft = Color(0xFFFEE2E2);

const Color zInfo = Color(0xFF0EA5E9);
const Color zInfoSoft = Color(0xFFE0F2FE);

const Color zWarning = Color(0xFFD97706);
const Color zWarningSoft = Color(0xFFFFEDD5);

const Color zLoginBg = Color(0xFFF5F5F4);
const Color zSurface = Colors.white;
const Color zSurfaceSoft = Color(0xFFFAFAFA);

const double kAppRadiusXs = 10;
const double kAppRadiusSm = 12;
const double kAppRadiusMd = 14;
const double kAppRadiusLg = 18;
const double kAppRadiusXl = 24;

const double kCardElevation = 0;
const double kSectionGap = 16;
const double kPagePadding = 20;

const String kAppName = 'MEMCO ERP';
const String kAppTagline = 'Industrial Automation ERP';

MaterialColor createMaterialColor(Color color) {
  final strengths = <double>[.05];
  final swatch = <int, Color>{};
  final int r = (color.r * 255.0).round() & 0xff;
  final int g = (color.g * 255.0).round() & 0xff;
  final int b = (color.b * 255.0).round() & 0xff;

  for (int i = 1; i < 10; i++) {
    strengths.add(0.1 * i);
  }

  for (final strength in strengths) {
    final double ds = 0.5 - strength;
    swatch[(strength * 1000).round()] = Color.fromRGBO(
      r + ((ds < 0 ? r : (255 - r)) * ds).round(),
      g + ((ds < 0 ? g : (255 - g)) * ds).round(),
      b + ((ds < 0 ? b : (255 - b)) * ds).round(),
      1,
    );
  }

  return MaterialColor(color.toARGB32(), swatch);
}

ThemeData buildQuikTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: zBlue,
    brightness: Brightness.light,
    primary: zBlue,
    secondary: zDarkBar,
    surface: zSurface,
    error: zDanger,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: zCanvasBg,
    primarySwatch: createMaterialColor(zBlue),
    colorScheme: colorScheme,
    fontFamily: 'Inter',
  );

  return base.copyWith(
    canvasColor: zCanvasBg,
    splashColor: zBlue.withValues(alpha: 0.08),
    highlightColor: zBlue.withValues(alpha: 0.04),

    textTheme: base.textTheme.copyWith(
      headlineLarge: const TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        color: zText,
        height: 1.2,
      ),
      headlineMedium: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: zText,
        height: 1.25,
      ),
      headlineSmall: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: zText,
        height: 1.3,
      ),
      titleLarge: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: zText,
        height: 1.3,
      ),
      titleMedium: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: zText,
        height: 1.35,
      ),
      titleSmall: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: zText,
        height: 1.35,
      ),
      bodyLarge: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: zText,
        height: 1.5,
      ),
      bodyMedium: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: zText,
        height: 1.5,
      ),
      bodySmall: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
        color: zMuted,
        height: 1.45,
      ),
      labelLarge: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: zText,
      ),
      labelMedium: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: zText,
      ),
      labelSmall: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: zMuted,
      ),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: zText,
      elevation: 0,
      centerTitle: false,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: zText,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
      iconTheme: IconThemeData(color: zText, size: 20),
    ),

    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: kCardElevation,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withValues(alpha: 0.04),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kAppRadiusLg),
        side: const BorderSide(color: zBorder),
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kAppRadiusXl),
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: zBorder,
      thickness: 1,
      space: 1,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      hintStyle: const TextStyle(
        color: zMuted,
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
      ),
      labelStyle: const TextStyle(
        color: zMuted,
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
      ),
      errorStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kAppRadiusMd),
        borderSide: const BorderSide(color: zBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kAppRadiusMd),
        borderSide: const BorderSide(color: zBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kAppRadiusMd),
        borderSide: const BorderSide(color: zBlue, width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kAppRadiusMd),
        borderSide: const BorderSide(color: zDanger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kAppRadiusMd),
        borderSide: const BorderSide(color: zDanger, width: 1.2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kAppRadiusMd),
        borderSide: const BorderSide(color: zBorder),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: zBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kAppRadiusMd),
        ),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: zBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kAppRadiusMd),
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: zText,
        backgroundColor: Colors.white,
        elevation: 0,
        side: const BorderSide(color: zBorder),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kAppRadiusMd),
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: zBlue,
        textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kAppRadiusSm),
        ),
      ),
    ),

    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      side: const BorderSide(color: zBorder),
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return zBlue;
        return Colors.white;
      }),
      checkColor: WidgetStateProperty.all(Colors.white),
      visualDensity: VisualDensity.compact,
    ),

    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return zBlue;
        return zMuted;
      }),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.white;
        return Colors.white;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return zBlue;
        return zMuted.withValues(alpha: 0.35);
      }),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: zSurfaceSoft,
      selectedColor: zBlueSoft,
      disabledColor: zBorder,
      deleteIconColor: zMuted,
      labelStyle: const TextStyle(
        color: zText,
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
      ),
      secondaryLabelStyle: const TextStyle(
        color: zBlue,
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: const BorderSide(color: zBorder),
      ),
      side: const BorderSide(color: zBorder),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: zText,
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kAppRadiusMd),
      ),
    ),

    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: zText.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(kAppRadiusSm),
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      waitDuration: const Duration(milliseconds: 300),
    ),

    popupMenuTheme: PopupMenuThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kAppRadiusLg),
        side: const BorderSide(color: zBorder),
      ),
      textStyle: const TextStyle(
        color: zText,
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
      ),
    ),

    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStateProperty.all(zSurfaceSoft),
      dataRowColor: WidgetStateProperty.all(Colors.white),
      headingTextStyle: const TextStyle(
        color: zMuted,
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
      ),
      dataTextStyle: const TextStyle(
        color: zText,
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
      ),
      dividerThickness: 1,
      horizontalMargin: 16,
      columnSpacing: 18,
      headingRowHeight: 48,
      dataRowMinHeight: 52,
      dataRowMaxHeight: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kAppRadiusLg),
        border: Border.all(color: zBorder),
      ),
    ),

    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      iconColor: zMuted,
      textColor: zText,
      titleTextStyle: TextStyle(
        color: zText,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
      subtitleTextStyle: TextStyle(
        color: zMuted,
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
      ),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: zBlue,
      linearTrackColor: zBorder,
      circularTrackColor: zBorder,
    ),
  );
}
