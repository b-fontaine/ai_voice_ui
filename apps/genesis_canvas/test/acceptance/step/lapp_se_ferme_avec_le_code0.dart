import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

/// Usage: l'app se ferme avec le code 0
Future<void> lappSeFermeAvecLeCode0(WidgetTester tester) async {
  expect(Harness.exitCodes, <int>[0]);
}
