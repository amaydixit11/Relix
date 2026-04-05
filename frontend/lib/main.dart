import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: primary,
              brightness: Brightness.dark,
              surface: surface,
              onSurface: Colors.white,
              primary: primary,
              secondary: const Color(0xFFA267F6),
              tertiary: const Color(0xFF2DD4BF),
            ),
            scaffoldBackgroundColor: background,
            textTheme: GoogleFonts.interTextTheme(
              const TextTheme(
                headlineLarge: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.5,
                  fontSize: 32,
                  color: Colors.white,
                ),
                headlineMedium: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                  color: Colors.white,
                ),
                bodyMedium: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: Colors.white70,
                ),
              ),
            ),
            cardTheme: CardThemeData(
              color: surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: borderColor),
              ),
            ),
            dividerTheme: const DividerThemeData(
              space: 1,
              thickness: 1,
              color: borderColor,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: surface,
              elevation: 0,
              centerTitle: false,
              titleTextStyle: TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                fontSize: 12,
                color: primary,
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.black.withOpacity(0.3),
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
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
            ),
          ),
          home: HomePage(controller: controller),
        );
      },
    );
  }
}
