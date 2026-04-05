import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relix_flutter/pages/home_page.dart';
import 'package:relix_flutter/services/relix_controller.dart';

void main() {
  testWidgets('relix home shell renders', (tester) async {
    final controller = RelixController();

    await tester.pumpWidget(
      MaterialApp(home: HomePage(controller: controller)),
    );

    expect(find.text('Your Vault'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
