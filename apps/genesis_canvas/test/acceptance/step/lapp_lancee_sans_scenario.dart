import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

/// Usage: l'app lancée sans scénario
Future<void> lappLanceeSansScenario(WidgetTester tester) async {
  await Harness.launch(tester);
}
