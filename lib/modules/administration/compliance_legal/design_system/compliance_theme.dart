import 'package:flutter/material.dart';

import 'package:QUIK/core/theme/theme_controller.dart';

@immutable
class CompliancePalette extends ThemeExtension<CompliancePalette> {
  const CompliancePalette({
    required this.canvas,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceMuted,
    required this.sidebar,
    required this.sidebarSelected,
    required this.sidebarText,
    required this.sidebarTextMuted,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.primary,
    required this.primaryHover,
    required this.primarySoft,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.info,
    required this.infoSoft,
    required this.legal,
    required this.legalSoft,
    required this.audit,
    required this.auditSoft,
    required this.shadow,
    required this.scrim,
  });

  final Color canvas;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceMuted;
  final Color sidebar;
  final Color sidebarSelected;
  final Color sidebarText;
  final Color sidebarTextMuted;
  final Color border;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color primary;
  final Color primaryHover;
  final Color primarySoft;
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;
  final Color info;
  final Color infoSoft;
  final Color legal;
  final Color legalSoft;
  final Color audit;
  final Color auditSoft;
  final Color shadow;
  final Color scrim;

  static const CompliancePalette light = CompliancePalette(
    canvas: Color(0xFFF3F6FA),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF7F9FC),
    sidebar: Color(0xFF0F1F36),
    sidebarSelected: Color(0xFF1A3A66),
    sidebarText: Color(0xFFFFFFFF),
    sidebarTextMuted: Color(0xFFAEBBD0),
    border: Color(0xFFE1E7EF),
    borderStrong: Color(0xFFC9D4E1),
    textPrimary: Color(0xFF14233A),
    textSecondary: Color(0xFF53657A),
    textTertiary: Color(0xFF7B8B9E),
    primary: Color(0xFF1769E0),
    primaryHover: Color(0xFF0F57C4),
    primarySoft: Color(0xFFEAF2FF),
    success: Color(0xFF168A4B),
    successSoft: Color(0xFFE7F7EE),
    warning: Color(0xFFD97706),
    warningSoft: Color(0xFFFFF4E5),
    danger: Color(0xFFC93636),
    dangerSoft: Color(0xFFFDECEC),
    info: Color(0xFF0284C7),
    infoSoft: Color(0xFFE8F6FC),
    legal: Color(0xFF7347C8),
    legalSoft: Color(0xFFF2ECFC),
    audit: Color(0xFF334155),
    auditSoft: Color(0xFFEEF2F6),
    shadow: Color(0x1A14233A),
    scrim: Color(0x80102030),
  );

  static const CompliancePalette dark = CompliancePalette(
    canvas: Color(0xFF07111F),
    surface: Color(0xFF101B2C),
    surfaceRaised: Color(0xFF162338),
    surfaceMuted: Color(0xFF18263A),
    sidebar: Color(0xFF081321),
    sidebarSelected: Color(0xFF17365F),
    sidebarText: Color(0xFFFFFFFF),
    sidebarTextMuted: Color(0xFFAAB9CC),
    border: Color(0xFF293A51),
    borderStrong: Color(0xFF3B506D),
    textPrimary: Color(0xFFF3F7FC),
    textSecondary: Color(0xFFB4C1D0),
    textTertiary: Color(0xFF8798AD),
    primary: Color(0xFF68A1F2),
    primaryHover: Color(0xFF8BB7F6),
    primarySoft: Color(0xFF142E52),
    success: Color(0xFF4EC783),
    successSoft: Color(0xFF133622),
    warning: Color(0xFFF1AD4E),
    warningSoft: Color(0xFF3A2A13),
    danger: Color(0xFFF07171),
    dangerSoft: Color(0xFF3C1E24),
    info: Color(0xFF55BDEB),
    infoSoft: Color(0xFF123348),
    legal: Color(0xFFB493EC),
    legalSoft: Color(0xFF2C2241),
    audit: Color(0xFFC0CAD7),
    auditSoft: Color(0xFF253246),
    shadow: Color(0x66000000),
    scrim: Color(0xB3000000),
  );

  static CompliancePalette resolve(BuildContext context) {
    return Theme.of(context).extension<CompliancePalette>() ??
        (Theme.of(context).brightness == Brightness.dark ? dark : light);
  }

  @override
  CompliancePalette copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceMuted,
    Color? sidebar,
    Color? sidebarSelected,
    Color? sidebarText,
    Color? sidebarTextMuted,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? primary,
    Color? primaryHover,
    Color? primarySoft,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? warningSoft,
    Color? danger,
    Color? dangerSoft,
    Color? info,
    Color? infoSoft,
    Color? legal,
    Color? legalSoft,
    Color? audit,
    Color? auditSoft,
    Color? shadow,
    Color? scrim,
  }) {
    return CompliancePalette(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      sidebar: sidebar ?? this.sidebar,
      sidebarSelected: sidebarSelected ?? this.sidebarSelected,
      sidebarText: sidebarText ?? this.sidebarText,
      sidebarTextMuted: sidebarTextMuted ?? this.sidebarTextMuted,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      primary: primary ?? this.primary,
      primaryHover: primaryHover ?? this.primaryHover,
      primarySoft: primarySoft ?? this.primarySoft,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      info: info ?? this.info,
      infoSoft: infoSoft ?? this.infoSoft,
      legal: legal ?? this.legal,
      legalSoft: legalSoft ?? this.legalSoft,
      audit: audit ?? this.audit,
      auditSoft: auditSoft ?? this.auditSoft,
      shadow: shadow ?? this.shadow,
      scrim: scrim ?? this.scrim,
    );
  }

  @override
  CompliancePalette lerp(
    covariant ThemeExtension<CompliancePalette>? other,
    double t,
  ) {
    if (other is! CompliancePalette) {
      return this;
    }

    Color mix(Color first, Color second) => Color.lerp(first, second, t)!;

    return CompliancePalette(
      canvas: mix(canvas, other.canvas),
      surface: mix(surface, other.surface),
      surfaceRaised: mix(surfaceRaised, other.surfaceRaised),
      surfaceMuted: mix(surfaceMuted, other.surfaceMuted),
      sidebar: mix(sidebar, other.sidebar),
      sidebarSelected: mix(sidebarSelected, other.sidebarSelected),
      sidebarText: mix(sidebarText, other.sidebarText),
      sidebarTextMuted: mix(sidebarTextMuted, other.sidebarTextMuted),
      border: mix(border, other.border),
      borderStrong: mix(borderStrong, other.borderStrong),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      textTertiary: mix(textTertiary, other.textTertiary),
      primary: mix(primary, other.primary),
      primaryHover: mix(primaryHover, other.primaryHover),
      primarySoft: mix(primarySoft, other.primarySoft),
      success: mix(success, other.success),
      successSoft: mix(successSoft, other.successSoft),
      warning: mix(warning, other.warning),
      warningSoft: mix(warningSoft, other.warningSoft),
      danger: mix(danger, other.danger),
      dangerSoft: mix(dangerSoft, other.dangerSoft),
      info: mix(info, other.info),
      infoSoft: mix(infoSoft, other.infoSoft),
      legal: mix(legal, other.legal),
      legalSoft: mix(legalSoft, other.legalSoft),
      audit: mix(audit, other.audit),
      auditSoft: mix(auditSoft, other.auditSoft),
      shadow: mix(shadow, other.shadow),
      scrim: mix(scrim, other.scrim),
    );
  }
}

abstract final class ComplianceSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
}

abstract final class ComplianceRadius {
  static const double xs = 6;
  static const double sm = 8;
  static const double md = 10;
  static const double lg = 14;
  static const double xl = 18;
  static const double xxl = 24;
  static const double pill = 999;
}

abstract final class ComplianceMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 320);
  static const Curve standard = Curves.easeOutCubic;
}

enum ComplianceTone {
  neutral,
  primary,
  success,
  warning,
  danger,
  info,
  legal,
  audit,
}

extension ComplianceContextX on BuildContext {
  CompliancePalette get compliance => CompliancePalette.resolve(this);

  bool get isComplianceDark => Theme.of(this).brightness == Brightness.dark;

  Color complianceTone(ComplianceTone tone) {
    final palette = compliance;
    return switch (tone) {
      ComplianceTone.neutral => palette.textSecondary,
      ComplianceTone.primary => palette.primary,
      ComplianceTone.success => palette.success,
      ComplianceTone.warning => palette.warning,
      ComplianceTone.danger => palette.danger,
      ComplianceTone.info => palette.info,
      ComplianceTone.legal => palette.legal,
      ComplianceTone.audit => palette.audit,
    };
  }

  Color complianceToneSoft(ComplianceTone tone) {
    final palette = compliance;
    return switch (tone) {
      ComplianceTone.neutral => palette.surfaceMuted,
      ComplianceTone.primary => palette.primarySoft,
      ComplianceTone.success => palette.successSoft,
      ComplianceTone.warning => palette.warningSoft,
      ComplianceTone.danger => palette.dangerSoft,
      ComplianceTone.info => palette.infoSoft,
      ComplianceTone.legal => palette.legalSoft,
      ComplianceTone.audit => palette.auditSoft,
    };
  }
}

/// Applies the blue Compliance visual language while continuing to inherit the
/// app-wide light/dark [ThemeMode]. Every Compliance route should use this at
/// its root so dialogs, popup menus, date pickers, tables and controls adapt
/// automatically.
class ComplianceThemeShell extends StatelessWidget {
  const ComplianceThemeShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final inherited = Theme.of(context);
    final dark = inherited.brightness == Brightness.dark;
    final palette = dark ? CompliancePalette.dark : CompliancePalette.light;

    final scheme =
        ColorScheme.fromSeed(
          seedColor: palette.primary,
          brightness: inherited.brightness,
          primary: palette.primary,
          secondary: palette.info,
          surface: palette.surface,
          error: palette.danger,
        ).copyWith(
          onSurface: palette.textPrimary,
          onSurfaceVariant: palette.textSecondary,
          outline: palette.borderStrong,
          outlineVariant: palette.border,
          surfaceContainerLowest: palette.canvas,
          surfaceContainerLow: palette.surfaceMuted,
          surfaceContainer: palette.surface,
          surfaceContainerHigh: palette.surfaceRaised,
          surfaceContainerHighest: palette.surfaceRaised,
        );

    final textTheme = inherited.textTheme.apply(
      bodyColor: palette.textPrimary,
      displayColor: palette.textPrimary,
    );

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(ComplianceRadius.md),
      borderSide: BorderSide(color: palette.border),
    );

    final mergedExtensions = inherited.extensions.values
        .where((extension) => extension is! CompliancePalette)
        .toList(growable: true);

    mergedExtensions.add(palette);

    final theme = inherited.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.canvas,
      canvasColor: palette.canvas,
      cardColor: palette.surface,
      dividerColor: palette.border,
      textTheme: textTheme,
      extensions: mergedExtensions,

      appBarTheme: inherited.appBarTheme.copyWith(
        backgroundColor: palette.surface,
        foregroundColor: palette.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shadowColor: palette.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ComplianceRadius.lg),
          side: BorderSide(color: palette.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 18,
        shadowColor: palette.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ComplianceRadius.xxl),
          side: BorderSide(color: palette.border),
        ),
      ),
      inputDecorationTheme: inherited.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: palette.surface,
        prefixIconColor: palette.textSecondary,
        suffixIconColor: palette.textSecondary,
        labelStyle: TextStyle(
          color: palette.textSecondary,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: TextStyle(color: palette.textTertiary),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: palette.primary, width: 1.5),
        ),
        errorBorder: border.copyWith(
          borderSide: BorderSide(color: palette.danger),
        ),
        focusedErrorBorder: border.copyWith(
          borderSide: BorderSide(color: palette.danger, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: palette.border,
          disabledForegroundColor: palette.textTertiary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ComplianceRadius.md),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          backgroundColor: palette.surface,
          side: BorderSide(color: palette.borderStrong),
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ComplianceRadius.md),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ComplianceRadius.sm),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: palette.textSecondary,
          hoverColor: palette.primarySoft,
          highlightColor: palette.primarySoft,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ComplianceRadius.sm),
          ),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(palette.surfaceMuted),
        dataRowColor: WidgetStatePropertyAll(palette.surface),
        headingTextStyle: TextStyle(
          color: palette.textSecondary,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
        dataTextStyle: TextStyle(
          color: palette.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        dividerThickness: 1,
        headingRowHeight: 46,
        dataRowMinHeight: 50,
        dataRowMaxHeight: 66,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 16,
        shadowColor: palette.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ComplianceRadius.lg),
          side: BorderSide(color: palette.border),
        ),
        textStyle: TextStyle(
          color: palette.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(palette.surfaceRaised),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(16),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ComplianceRadius.lg),
              side: BorderSide(color: palette.border),
            ),
          ),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: palette.surface,
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: BorderSide(color: palette.primary, width: 1.5),
          ),
        ),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(palette.surfaceRaised),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: palette.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: palette.surfaceMuted,
        headerForegroundColor: palette.textPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ComplianceRadius.xxl),
          side: BorderSide(color: palette.border),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: palette.surfaceRaised,
        dialBackgroundColor: palette.surfaceMuted,
        hourMinuteColor: palette.surfaceMuted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ComplianceRadius.xxl),
          side: BorderSide(color: palette.border),
        ),
      ),
      chipTheme: inherited.chipTheme.copyWith(
        backgroundColor: palette.surfaceMuted,
        selectedColor: palette.primarySoft,
        side: BorderSide(color: palette.border),
        labelStyle: TextStyle(
          color: palette.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ComplianceRadius.pill),
        ),
      ),
      snackBarTheme: inherited.snackBarTheme.copyWith(
        backgroundColor: dark ? palette.surfaceRaised : const Color(0xFF14233A),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ComplianceRadius.md),
        ),
      ),
      tooltipTheme: inherited.tooltipTheme.copyWith(
        decoration: BoxDecoration(
          color: dark ? palette.surfaceRaised : const Color(0xFF14233A),
          borderRadius: BorderRadius.circular(ComplianceRadius.sm),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      scrollbarTheme: inherited.scrollbarTheme.copyWith(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return palette.textTertiary.withValues(
            alpha: states.contains(WidgetState.hovered) ? .62 : .36,
          );
        }),
        trackColor: WidgetStatePropertyAll(
          palette.border.withValues(alpha: .45),
        ),
        thickness: const WidgetStatePropertyAll(8),
        radius: const Radius.circular(ComplianceRadius.pill),
      ),
    );

    return AnimatedTheme(
      data: theme,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      child: child,
    );
  }
}

class ComplianceThemeToggleButton extends StatelessWidget {
  const ComplianceThemeToggleButton({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final dark = QuikThemeController.instance.isDark(context);

    return IconButton(
      tooltip: dark ? 'Switch to light mode' : 'Switch to dark mode',
      onPressed: () => QuikThemeController.instance.toggle(context),
      icon: AnimatedSwitcher(
        duration: ComplianceMotion.normal,
        transitionBuilder: (child, animation) => RotationTransition(
          turns: Tween<double>(begin: .8, end: 1).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: Icon(
          dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          key: ValueKey(dark),
          size: compact ? 19 : 21,
        ),
      ),
    );
  }
}
