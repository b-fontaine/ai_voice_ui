import 'package:flutter_test/flutter_test.dart';

import '../support/acte4_harness.dart';

/// Usage: le rejeu n'est pas terminé
Future<void> leRejeuNestPasTermine(WidgetTester tester) async {
  expect(
    Acte4Harness.isEnded(tester),
    isFalse,
    reason: 'le rejeu ne devrait pas être à sa dernière image',
  );
}
