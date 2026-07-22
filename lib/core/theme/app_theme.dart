import 'package:flutter/material.dart';

import 'package:QUIK/modules/administration/compliance_legal/design_system/compliance_theme.dart';

// ---------------------------------------------------------------------------
// MEMCO ERP design tokens
// ---------------------------------------------------------------------------

const String kAppName = 'MEMCO ERP';
const String kAppTagline = 'Industrial Automation ERP';

abstract final class QuikColors {
  // MEMCO brand colors used by the main ERP shell.
  static const Color brand = Color(0xFFF97316);
  static const Color brandDark = Color(0xFFEA580C);
  static const Color brandDeep = Color(0xFFC2410C);

  // Compliance uses blue as its semantic primary through its own design
  // system. These app colors remain stable for the wider ERP shell.
  static const Color blue = Color(0xFF1769E0);
  static const Color blueDark = Color(0xFF0F4FB4);

  static const Color success = Color(0xFF168A4B);
  static const Color warning = Color(0xFFD97706);
  static const Color danger = Color(0xFFDC2626);
  static const Color info = Color(0xFF0284C7);
  static const Color legal = Color(0xFF7C3AED);

  static const Color lightCanvas = Color(0xFFF4F6F9);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceMuted = Color(0xFFF8FAFC);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightBorderStrong = Color(0xFFCBD5E1);
  static const Color lightText = Color(0xFF172033);
  static const Color lightMuted = Color(0xFF64748B);

  static const Color darkCanvas = Color(0xFF08111F);
  static const Color darkSurface = Color(0xFF101A2B);
  static const Color darkSurfaceMuted = Color(0xFF172235);
  static const Color darkSurfaceElevated = Color(0xFF1B2940);
  static const Color darkBorder = Color(0xFF2A3950);
  static const Color darkBorderStrong = Color(0xFF3B4D66);
  static const Color darkText = Color(0xFFF3F7FC);
  static const Color darkMuted = Color(0xFFA6B4C6);
}

// Existing aliases are intentionally retained so unrelated ERP modules keep
// compiling while the theme implementation becomes light/dark capable.
const Color zMemcoOrange = QuikColors.brand;
const Color zMemcoOrangeDark = QuikColors.brandDark;
const Color zMemcoBlack = Color(0xFF111111);
const Color zMemcoGraphite = Color(0xFF2B2F33);
const Color zMemcoDarkGray = Color(0xFF3F3F46);
const Color zMemcoCanvas = QuikColors.lightCanvas;
const Color zTealTop = Color(0xFF2B2F33);
const Color zDarkBar = Color(0xFF111111);
const Color zIconRail = Color(0xFF18181B);
const Color zSidebarBg = Color(0xFFF5F5F4);
const Color zCanvasBg = QuikColors.lightCanvas;
const Color zBorder = QuikColors.lightBorder;
const Color zText = QuikColors.lightText;
const Color zMuted = QuikColors.lightMuted;
const Color zBlue = QuikColors.brand;
const Color zBlueDark = QuikColors.brandDark;
const Color zBlueDeep = QuikColors.brandDeep;
const Color zBlueSoft = Color(0xFFFFF7ED);
const Color zSuccess = QuikColors.success;
const Color zSuccessSoft = Color(0xFFDCFCE7);
const Color zOrange = QuikColors.brand;
const Color zOrangeSoft = Color(0xFFFFF7ED);
const Color zPurple = QuikColors.legal;
const Color zPurpleSoft = Color(0xFFF3E8FF);
const Color zDanger = QuikColors.danger;
const Color zDangerSoft = Color(0xFFFEE2E2);
const Color zInfo = QuikColors.info;
const Color zInfoSoft = Color(0xFFE0F2FE);
const Color zWarning = QuikColors.warning;
const Color zWarningSoft = Color(0xFFFFEDD5);
const Color zLoginBg = Color(0xFFF5F5F4);
const Color zSurface = QuikColors.lightSurface;
const Color zSurfaceSoft = QuikColors.lightSurfaceMuted;

abstract final class QuikRadii {
  static const double xs = 8;
  static const double sm = 10;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 22;
  static const double pill = 999;
}

abstract final class QuikSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
}

const double kAppRadiusXs = QuikRadii.sm;
const double kAppRadiusSm = QuikRadii.md;
const double kAppRadiusMd = QuikRadii.lg;
const double kAppRadiusLg = 18;
const double kAppRadiusXl = QuikRadii.xl;
const double kCardElevation = 0;
const double kSectionGap = QuikSpacing.md;
const double kPagePadding = QuikSpacing.lg;

MaterialColor createMaterialColor(Color color) {
  final strengths = <double>[.05];
  final swatch = <int, Color>{};
  final r = (color.r * 255.0).round() & 0xff;
  final g = (color.g * 255.0).round() & 0xff;
  final b = (color.b * 255.0).round() & 0xff;

  for (var index = 1; index < 10; index++) {
    strengths.add(0.1 * index);
  }

  for (final strength in strengths) {
    final delta = 0.5 - strength;
    swatch[(strength * 1000).round()] = Color.fromRGBO(
      r + ((delta < 0 ? r : 255 - r) * delta).round(),
      g + ((delta < 0 ? g : 255 - g) * delta).round(),
      b + ((delta < 0 ? b : 255 - b) * delta).round(),
      1,
    );
  }

  return MaterialColor(color.toARGB32(), swatch);
}

ThemeData buildQuikLightTheme() => _buildQuikTheme(Brightness.light);
ThemeData buildQuikDarkTheme() => _buildQuikTheme(Brightness.dark);

/// Backwards-compatible alias used by older files.
ThemeData buildQuikTheme() => buildQuikLightTheme();

ThemeData _buildQuikTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final canvas = dark ? QuikColors.darkCanvas : QuikColors.lightCanvas;
  final surface = dark ? QuikColors.darkSurface : QuikColors.lightSurface;
  final surfaceMuted = dark
      ? QuikColors.darkSurfaceMuted
      : QuikColors.lightSurfaceMuted;
  final border = dark ? QuikColors.darkBorder : QuikColors.lightBorder;
  final borderStrong = dark
      ? QuikColors.darkBorderStrong
      : QuikColors.lightBorderStrong;
  final text = dark ? QuikColors.darkText : QuikColors.lightText;
  final muted = dark ? QuikColors.darkMuted : QuikColors.lightMuted;

  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: QuikColors.brand,
        brightness: brightness,
        primary: QuikColors.brand,
        secondary: QuikColors.blue,
        surface: surface,
        error: QuikColors.danger,
      ).copyWith(
        onSurface: text,
        onSurfaceVariant: muted,
        outline: borderStrong,
        outlineVariant: border,
        surfaceContainerLowest: canvas,
        surfaceContainerLow: surfaceMuted,
        surfaceContainer: surface,
        surfaceContainerHigh: dark
            ? QuikColors.darkSurfaceElevated
            : QuikColors.lightSurface,
        surfaceContainerHighest: dark
            ? const Color(0xFF213049)
            : const Color(0xFFF1F5F9),
      );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: canvas,
    primarySwatch: createMaterialColor(QuikColors.brand),
    colorScheme: colorScheme,
    fontFamily: 'Inter',
    visualDensity: VisualDensity.standard,
    extensions: <ThemeExtension<dynamic>>[
      dark ? CompliancePalette.dark : CompliancePalette.light,
    ],
  );

  final textTheme = base.textTheme
      .apply(bodyColor: text, displayColor: text)
      .copyWith(
        displayLarge: TextStyle(
          fontSize: 38,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.2,
          height: 1.1,
          color: text,
        ),
        headlineLarge: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          letterSpacing: -.7,
          height: 1.2,
          color: text,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          letterSpacing: -.45,
          height: 1.25,
          color: text,
        ),
        headlineSmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -.25,
          height: 1.3,
          color: text,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          height: 1.3,
          color: text,
        ),
        titleMedium: TextStyle(
          fontSize: 15.5,
          fontWeight: FontWeight.w700,
          height: 1.35,
          color: text,
        ),
        titleSmall: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          height: 1.35,
          color: text,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          height: 1.5,
          color: text,
        ),
        bodyMedium: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
          height: 1.5,
          color: text,
        ),
        bodySmall: TextStyle(
          fontSize: 12.25,
          fontWeight: FontWeight.w500,
          height: 1.45,
          color: muted,
        ),
        labelLarge: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: text,
        ),
        labelMedium: TextStyle(
          fontSize: 12.25,
          fontWeight: FontWeight.w700,
          color: text,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: muted,
        ),
      );

  final cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(QuikRadii.lg),
    side: BorderSide(color: border),
  );

  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(QuikRadii.md),
    borderSide: BorderSide(color: border),
  );

  return base.copyWith(
    canvasColor: canvas,
    cardColor: surface,
    dividerColor: border,
    disabledColor: muted.withValues(alpha: .44),
    splashColor: QuikColors.brand.withValues(alpha: .08),
    highlightColor: QuikColors.brand.withValues(alpha: .04),
    textTheme: textTheme,
    iconTheme: IconThemeData(color: muted, size: 20),
    primaryIconTheme: const IconThemeData(color: QuikColors.brand),
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      foregroundColor: text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
      iconTheme: IconThemeData(color: text, size: 20),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withValues(alpha: dark ? .20 : .06),
      margin: EdgeInsets.zero,
      shape: cardShape,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 18,
      shadowColor: Colors.black.withValues(alpha: dark ? .40 : .16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(QuikRadii.xl),
        side: BorderSide(color: border),
      ),
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      modalBackgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(QuikRadii.xl)),
      ),
    ),
    dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: textTheme.bodyMedium?.copyWith(color: muted),
      labelStyle: textTheme.bodyMedium?.copyWith(
        color: muted,
        fontWeight: FontWeight.w600,
      ),
      helperStyle: textTheme.bodySmall,
      errorStyle: textTheme.bodySmall?.copyWith(
        color: QuikColors.danger,
        fontWeight: FontWeight.w600,
      ),
      prefixIconColor: muted,
      suffixIconColor: muted,
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: QuikColors.brand, width: 1.5),
      ),
      errorBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: QuikColors.danger),
      ),
      focusedErrorBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: QuikColors.danger, width: 1.5),
      ),
      disabledBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: border.withValues(alpha: .7)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: QuikColors.brand,
        foregroundColor: Colors.white,
        disabledBackgroundColor: border,
        disabledForegroundColor: muted,
        elevation: 0,
        textStyle: textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(QuikRadii.md),
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: QuikColors.brand,
        foregroundColor: Colors.white,
        elevation: 0,
        textStyle: textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(QuikRadii.md),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: text,
        backgroundColor: surface,
        elevation: 0,
        side: BorderSide(color: borderStrong),
        textStyle: textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(QuikRadii.md),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: QuikColors.brand,
        textStyle: textTheme.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(QuikRadii.sm),
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: muted,
        hoverColor: QuikColors.brand.withValues(alpha: .08),
        highlightColor: QuikColors.brand.withValues(alpha: .06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(QuikRadii.sm),
        ),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      side: BorderSide(color: borderStrong),
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return QuikColors.brand;
        }
        return surface;
      }),
      checkColor: const WidgetStatePropertyAll(Colors.white),
      visualDensity: VisualDensity.compact,
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return QuikColors.brand;
        }
        return muted;
      }),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.white;
        }
        return dark ? QuikColors.darkText : Colors.white;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return QuikColors.brand;
        }
        return muted.withValues(alpha: .35);
      }),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surfaceMuted,
      selectedColor: QuikColors.brand.withValues(alpha: .12),
      disabledColor: border,
      deleteIconColor: muted,
      labelStyle: textTheme.labelMedium?.copyWith(color: text),
      secondaryLabelStyle: textTheme.labelMedium?.copyWith(
        color: QuikColors.brand,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(QuikRadii.pill),
        side: BorderSide(color: border),
      ),
      side: BorderSide(color: border),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: dark
          ? QuikColors.darkSurfaceElevated
          : QuikColors.lightText,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      behavior: SnackBarBehavior.floating,
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(QuikRadii.md),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: dark
            ? QuikColors.darkSurfaceElevated
            : QuikColors.lightText.withValues(alpha: .97),
        borderRadius: BorderRadius.circular(QuikRadii.sm),
      ),
      textStyle: textTheme.bodySmall?.copyWith(color: Colors.white),
      waitDuration: const Duration(milliseconds: 250),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: dark ? .35 : .12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(QuikRadii.lg),
        side: BorderSide(color: border),
      ),
      textStyle: textTheme.bodyMedium?.copyWith(
        color: text,
        fontWeight: FontWeight.w600,
      ),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(12),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(QuikRadii.lg),
            side: BorderSide(color: border),
          ),
        ),
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: QuikColors.brand, width: 1.5),
        ),
      ),
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    ),
    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStatePropertyAll(surfaceMuted),
      dataRowColor: WidgetStatePropertyAll(surface),
      headingTextStyle: textTheme.labelMedium?.copyWith(color: muted),
      dataTextStyle: textTheme.bodyMedium?.copyWith(
        color: text,
        fontWeight: FontWeight.w600,
      ),
      dividerThickness: 1,
      horizontalMargin: 16,
      columnSpacing: 18,
      headingRowHeight: 46,
      dataRowMinHeight: 50,
      dataRowMaxHeight: 64,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(QuikRadii.lg),
        border: Border.all(color: border),
      ),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      iconColor: muted,
      textColor: text,
      titleTextStyle: textTheme.bodyMedium?.copyWith(
        color: text,
        fontWeight: FontWeight.w700,
      ),
      subtitleTextStyle: textTheme.bodySmall?.copyWith(color: muted),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(QuikRadii.sm),
      ),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: surfaceMuted,
      headerForegroundColor: text,
      dayForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.white;
        }
        return text;
      }),
      dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return QuikColors.brand;
        }
        return Colors.transparent;
      }),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(QuikRadii.xl),
        side: BorderSide(color: border),
      ),
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: surface,
      dialBackgroundColor: surfaceMuted,
      hourMinuteColor: surfaceMuted,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(QuikRadii.xl),
        side: BorderSide(color: border),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: QuikColors.brand,
      linearTrackColor: border,
      circularTrackColor: border,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        final alpha = states.contains(WidgetState.hovered) ? .58 : .36;
        return muted.withValues(alpha: alpha);
      }),
      trackColor: WidgetStatePropertyAll(border.withValues(alpha: .45)),
      trackBorderColor: const WidgetStatePropertyAll(Colors.transparent),
      thickness: const WidgetStatePropertyAll(8),
      radius: const Radius.circular(QuikRadii.pill),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      },
    ),
  );
}
