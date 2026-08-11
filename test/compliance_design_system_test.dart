import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:QUIK/core/theme/app_theme.dart';
import 'package:QUIK/core/theme/theme_controller.dart';
import 'package:QUIK/modules/administration/compliance_legal/design_system/compliance_design_system.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Compliance enterprise design system', () {
    test('light and dark palettes expose accessible semantic tokens', () {
      expect(
        CompliancePalette.light.canvas,
        isNot(CompliancePalette.dark.canvas),
      );
      expect(
        CompliancePalette.light.textPrimary,
        isNot(CompliancePalette.dark.textPrimary),
      );
      expect(
        CompliancePalette.light.sidebarText,
        CompliancePalette.dark.sidebarText,
      );
      expect(
        CompliancePalette.light.success,
        isNot(CompliancePalette.light.danger),
      );
    });

    test('status labels map to stable semantic tones', () {
      expect(
        ComplianceStatusBadge.toneFor('Completed'),
        ComplianceTone.success,
      );
      expect(ComplianceStatusBadge.toneFor('Pending'), ComplianceTone.warning);
      expect(ComplianceStatusBadge.toneFor('Overdue'), ComplianceTone.danger);
      expect(ComplianceStatusBadge.toneFor('Litigation'), ComplianceTone.legal);
      expect(ComplianceStatusBadge.toneFor('Audit'), ComplianceTone.audit);
    });

    test('global theme mode is persisted', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final controller = QuikThemeController.instance;

      await controller.initialize();
      await controller.setThemeMode(ThemeMode.dark);

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('quik_erp_theme_mode_v2'), 'dark');
      expect(controller.themeMode, ThemeMode.dark);

      await controller.setThemeMode(ThemeMode.light);
      expect(preferences.getString('quik_erp_theme_mode_v2'), 'light');
    });

    testWidgets('compliance shell inherits the active dark theme', (
      tester,
    ) async {
      CompliancePalette? resolved;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildQuikLightTheme(),
          darkTheme: buildQuikDarkTheme(),
          themeMode: ThemeMode.dark,
          home: ComplianceThemeShell(
            child: Builder(
              builder: (context) {
                resolved = context.compliance;
                return const Scaffold(body: Text('Compliance'));
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Compliance'), findsOneWidget);
      expect(resolved?.canvas, CompliancePalette.dark.canvas);
      expect(resolved?.surface, CompliancePalette.dark.surface);
    });

    testWidgets('searchable selector opens an enterprise search dialog', (
      tester,
    ) async {
      String? selected;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildQuikLightTheme(),
          home: ComplianceThemeShell(
            child: Scaffold(
              body: ComplianceSelector<String>(
                label: 'Company',
                valueLabel: selected ?? 'Select Company',
                options: const <String>['MEMCO', 'MEMCO Infra'],
                labelBuilder: (value) => value,
                searchHint: 'Search Company',
                onSelected: (value) => selected = value,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Select Company'));
      await tester.pumpAndSettle();

      expect(find.text('Select Company'), findsWidgets);
      await tester.enterText(find.byType(TextField).last, 'Infra');
      await tester.pumpAndSettle();
      await tester.tap(find.text('MEMCO Infra'));
      await tester.pumpAndSettle();

      expect(selected, 'MEMCO Infra');
    });
  });
}
