import 'package:flutter/material.dart';

import '../../design_system/compliance_theme.dart';

/// Compatibility theme consumed by the existing Form 10-IEA widgets.
///
/// Every value is now sourced from the shared Compliance design system, so the
/// screen follows the application theme instantly and no longer carries the
/// previous lime-accent palette.
@immutable
class Form10IEATheme extends ThemeExtension<Form10IEATheme> {
  const Form10IEATheme({
    required this.accent,
    required this.accentForeground,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.success,
    required this.warning,
    required this.error,
  });

  final Color accent;
  final Color accentForeground;
  final Color surface;
  final Color surfaceMuted;
  final Color border;
  final Color success;
  final Color warning;
  final Color error;

  static Form10IEATheme resolve(BuildContext context) {
    final existing = Theme.of(context).extension<Form10IEATheme>();
    if (existing != null) {
      return existing;
    }

    final palette = context.compliance;
    final scheme = Theme.of(context).colorScheme;

    return Form10IEATheme(
      accent: palette.primary,
      accentForeground: scheme.onPrimary,
      surface: palette.surface,
      surfaceMuted: palette.surfaceMuted,
      border: palette.border,
      success: palette.success,
      warning: palette.warning,
      error: palette.danger,
    );
  }

  @override
  Form10IEATheme copyWith({
    Color? accent,
    Color? accentForeground,
    Color? surface,
    Color? surfaceMuted,
    Color? border,
    Color? success,
    Color? warning,
    Color? error,
  }) {
    return Form10IEATheme(
      accent: accent ?? this.accent,
      accentForeground: accentForeground ?? this.accentForeground,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      border: border ?? this.border,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
    );
  }

  @override
  Form10IEATheme lerp(
    covariant ThemeExtension<Form10IEATheme>? other,
    double t,
  ) {
    if (other is! Form10IEATheme) {
      return this;
    }

    return Form10IEATheme(
      accent: Color.lerp(accent, other.accent, t)!,
      accentForeground: Color.lerp(
        accentForeground,
        other.accentForeground,
        t,
      )!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
    );
  }
}
