import 'package:flutter/material.dart';

import 'pages/home_page.dart';
import 'services/relix_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = RelixController();
  await controller.initialize();
  runApp(RelixApp(controller: controller));
}

class RelixApp extends StatelessWidget {
  const RelixApp({super.key, required this.controller});

  final RelixController controller;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF2DD4BF);
    const background = Color(0xFF020617);
    const surface = Color(0xFF0F172A);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return MaterialApp(
          title: 'Relix',
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.dark,
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: primary,
              brightness: Brightness.dark,
              surface: surface,
              onSurface: Colors.white,
              primary: primary,
            ),
            scaffoldBackgroundColor: background,
            fontFamily: 'Inter', // Assuming standard font or similar
            textTheme: const TextTheme(
              headlineLarge: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: -1.5,
                color: Colors.white,
              ),
              headlineMedium: TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
                color: Colors.white,
              ),
              titleLarge: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            cardTheme: CardThemeData(
              color: surface.withValues(alpha: 0.8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
            ),
            navigationBarTheme: NavigationBarThemeData(
              backgroundColor: surface,
              indicatorColor: primary.withValues(alpha: 0.1),
              labelTextStyle: WidgetStateProperty.all(
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: surface.withValues(alpha: 0.5),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: primary, width: 1.5),
              ),
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            ),
          ),
          home: HomePage(controller: controller),
        );
      },
    );
  }
}
