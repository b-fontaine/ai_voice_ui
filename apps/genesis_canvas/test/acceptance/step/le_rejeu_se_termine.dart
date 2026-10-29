import 'package:flutter_test/flutter_test.dart';

/// Usage: le rejeu se termine
Future<void> leRejeuSeTermine(WidgetTester tester) async {
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 30),
  );
}
