import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'pages/home_page.dart';
import 'services/local_store.dart';
import 'services/relix_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = LocalStore();
  final controller = RelixController(store: store);
  await controller.initialize();
  final onboardingComplete = await store.readOnboardingComplete();
  runApp(
    RelixApp(
      controller: controller,
      store: store,
      onboardingComplete: onboardingComplete,
    ),
  );
}

class RelixApp extends StatefulWidget {
  const RelixApp({
    super.key,
    required this.controller,
    required this.store,
    required this.onboardingComplete,
  });

  final RelixController controller;
  final LocalStore store;
  final bool onboardingComplete;

  @override
  State<RelixApp> createState() => _RelixAppState();
}

class _RelixAppState extends State<RelixApp> {
  late bool _onboardingComplete = widget.onboardingComplete;

  Future<void> _completeOnboarding(String? baseUrl) async {
    final trimmed = baseUrl?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      await widget.controller.setBaseUrl(trimmed);
    }
    await widget.store.writeOnboardingComplete(true);
    if (mounted) {
      setState(() => _onboardingComplete = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF7B88FF); // Technically inspired blue/purple
    const background = Color(0xFF0F0F0F);
    const surface = Color(0xFF131313);
    const borderColor = Color(0xFF1F1F1F);

    return AnimatedBuilder(
      animation: widget.controller,
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
          home: _onboardingComplete
              ? HomePage(controller: widget.controller)
              : OnboardingPage(
                  controller: widget.controller,
                  onContinue: _completeOnboarding,
                ),
        );
      },
    );
  }
}

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    required this.controller,
    required this.onContinue,
  });

  final RelixController controller;
  final Future<void> Function(String? baseUrl) onContinue;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  late final TextEditingController _baseUrlController;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController(
      text: widget.controller.snapshot.baseUrl,
    );
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.controller.snapshot;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF050816), Color(0xFF111827), Color(0xFF08110F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'RELIX',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          color: Color(0xFF7B88FF),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Pair the device, then work locally.',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Relix talks to a local ACORDE daemon. Start with the default local URL for desktop development, or point this device at another reachable daemon before continuing.',
                      ),
                      const SizedBox(height: 28),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: const [
                          _OnboardingStat(
                            label: 'MODE',
                            value: 'LOCAL-FIRST',
                          ),
                          _OnboardingStat(
                            label: 'SYNC',
                            value: 'P2P',
                          ),
                          _OnboardingStat(
                            label: 'FORMAT',
                            value: 'MARKDOWN',
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      TextField(
                        controller: _baseUrlController,
                        decoration: const InputDecoration(
                          labelText: 'ACORDE base URL',
                          hintText: 'http://localhost:7331',
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        snapshot.daemonReachable
                            ? 'Daemon probe succeeded.'
                            : 'No daemon detected yet. You can still continue and update the URL later from Settings.',
                        style: TextStyle(
                          color: snapshot.daemonReachable
                              ? const Color(0xFF2DD4BF)
                              : Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: _submitting
                                ? null
                                : () => _baseUrlController.text =
                                      'http://localhost:7331',
                            child: const Text('USE_DEFAULT'),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: _submitting ? null : _submit,
                            child: Text(
                              _submitting ? 'CONNECTING...' : 'ENTER_VAULT',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await widget.onContinue(_baseUrlController.text);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}

class _OnboardingStat extends StatelessWidget {
  const _OnboardingStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F1F1F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white38,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
