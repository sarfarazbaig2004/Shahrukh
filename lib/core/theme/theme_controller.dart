import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide theme state used by the ERP shell and every Compliance route.
///
/// The preference is loaded before [runApp], so switching themes never causes a
/// white flash and the selected mode survives logout, browser refresh and app
/// restart.
class QuikThemeController extends ChangeNotifier {
  QuikThemeController._();

  static final QuikThemeController instance = QuikThemeController._();

  static const String _preferenceKey = 'quik_erp_theme_mode_v2';

  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;

  bool _initialized = false;
  bool get initialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_preferenceKey);

    // Migrate the earlier Compliance-only preference keys when present.
    final legacyCommandCenter = preferences.getString(
      'enterprise_compliance_command_center_theme',
    );
    final legacyCompliance = preferences.getBool('compliance_legal_dark_theme');

    _themeMode = switch (stored ?? legacyCommandCenter) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      'light' => ThemeMode.light,
      _ when legacyCompliance == true => ThemeMode.dark,
      _ => ThemeMode.light,
    };

    _initialized = true;
  }

  bool isDark(BuildContext context) {
    return switch (_themeMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system =>
        MediaQuery.platformBrightnessOf(context) == Brightness.dark,
    };
  }

  Future<void> toggle(BuildContext context) async {
    await setThemeMode(isDark(context) ? ThemeMode.light : ThemeMode.dark);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode && _initialized) {
      return;
    }

    _themeMode = mode;
    _initialized = true;
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_preferenceKey, switch (mode) {
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
      ThemeMode.light => 'light',
    });
  }
}
