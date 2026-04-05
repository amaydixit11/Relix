import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relix_flutter/main.dart';
import 'package:relix_flutter/models.dart';
import 'package:relix_flutter/pages/settings_page.dart';
import 'package:relix_flutter/services/relix_controller.dart';
import 'package:relix_flutter/widgets/connection_banner.dart';
import 'package:relix_flutter/widgets/note_card.dart';

void main() {
  testWidgets('connection banner renders offline state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ConnectionBanner(
            snapshot: SyncSnapshot(daemonReachable: false),
          ),
        ),
      ),
    );

    expect(find.text('Offline • working from local cache'), findsOneWidget);
  });

  testWidgets('note card renders note content', (tester) async {
    final note = NoteEntry(
      id: 'note-1',
      type: 'note',
      content: const NoteContent(title: 'Hello', body: 'Body preview'),
      tags: const ['tag-a'],
      createdAt: 1,
      updatedAt: 1,
      deleted: false,
      owner: 'local',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteCard(
            note: note,
            timeLabel: 'just now',
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('HELLO'), findsOneWidget);
    expect(find.text('Body preview'), findsOneWidget);
    expect(find.text('TAG-A'), findsOneWidget);
  });

  testWidgets('settings page renders pairing controls', (tester) async {
    final controller = RelixController();

    await tester.binding.setSurfaceSize(const Size(1440, 960));
    await tester.pumpWidget(
      MaterialApp(home: SettingsPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('FLEET COMMAND'), findsOneWidget);
    expect(find.text('GENERATE_CODE'), findsOneWidget);
    expect(find.text('DAEMON_UPLINK_ENDPOINT'), findsOneWidget);
  });

  testWidgets('onboarding page renders setup flow', (tester) async {
    final controller = RelixController();
    var continued = false;

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingPage(
          controller: controller,
          onContinue: (_) async {
            continued = true;
          },
        ),
      ),
    );

    expect(find.text('Pair the device, then work locally.'), findsOneWidget);
    expect(find.text('ENTER_VAULT'), findsOneWidget);

    await tester.tap(find.text('ENTER_VAULT'));
    await tester.pumpAndSettle();

    expect(continued, isTrue);
  });
}
