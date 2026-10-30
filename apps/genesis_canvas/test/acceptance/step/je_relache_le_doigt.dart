import 'package:flutter_test/flutter_test.dart';

import '../support/acte4_harness.dart';

/// Usage: je relâche le doigt
Future<void> jeRelacheLeDoigt(WidgetTester tester) async {
  await Acte4Harness.gesture!.up();
  Acte4Harness.gesture = null;
  await Acte4Harness.settle(tester);
}
