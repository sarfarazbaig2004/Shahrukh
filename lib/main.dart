import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'package:QUIK/auth/auth_wrapper.dart';
import 'package:QUIK/config/firebase_options.dart';
import 'package:QUIK/core/theme/app_theme.dart';
import 'package:QUIK/core/theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Future.wait(<Future<void>>[
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
    QuikThemeController.instance.initialize(),
  ]);

  runApp(const QuikApp());
}

class QuikApp extends StatelessWidget {
  const QuikApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: QuikThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          title: kAppName,
          debugShowCheckedModeBanner: false,
          theme: buildQuikLightTheme(),
          darkTheme: buildQuikDarkTheme(),
          themeMode: QuikThemeController.instance.themeMode,
          themeAnimationDuration: const Duration(milliseconds: 240),
          themeAnimationCurve: Curves.easeOutCubic,
          home: const AuthWrapper(),
        );
      },
    );
  }
}
