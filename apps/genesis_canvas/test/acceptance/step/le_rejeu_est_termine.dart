import 'package:flutter_test/flutter_test.dart';

import '../support/acte4_harness.dart';

/// Usage: le rejeu est terminé
Future<void> leRejeuEstTermine(WidgetTester tester) async {
  expect(
    Acte4Harness.isEnded(tester),
    isTrue,
    reason: 'le rejeu devrait être à sa dernière image',
  );
}
