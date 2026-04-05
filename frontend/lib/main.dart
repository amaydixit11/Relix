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
    const primary = Color(0xFF7B88FF); // Technically inspired blue/purple
    const background = Color(0xFF0F0F0F);
    const surface = Color(0xFF131313);
    const borderColor = Color(0xFF1F1F1F);

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
              secondary: const Color(0xFFA267F6),
            ),
            scaffoldBackgroundColor: background,
            fontFamily: 'Inter',
            textTheme: const TextTheme(
              headlineLarge: TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
                fontSize: 32,
                color: Colors.white,
              ),
              headlineMedium: TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                fontSize: 24,
                color: Colors.white,
              ),
              titleLarge: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: Colors.white,
              ),
              bodyMedium: TextStyle(
                fontSize: 14,
                color: Colors.white70,
                height: 1.6,
              ),
              labelSmall: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                letterSpacing: 2,
                fontWeight: FontWeight.w900,
                color: Colors.white24,
              ),
            ),
            dividerTheme: const DividerThemeData(
              color: borderColor,
              thickness: 1,
              space: 1,
            ),
            cardTheme: CardThemeData(
              color: surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: borderColor),
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
              fillColor: Colors.black.withValues(alpha: 0.3),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: primary, width: 1.5),
              ),
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
            ),
          ),
          home: HomePage(controller: controller),
        );
      },
    );
  }
}
