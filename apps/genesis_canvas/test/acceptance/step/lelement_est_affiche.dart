import 'package:flutter_test/flutter_test.dart';

import '../support/fidelity_harness.dart';

/// Usage: l'élément {'checklist-head-3'} est affiché
Future<void> lelementEstAffiche(WidgetTester tester, String element) async {
  Fidelity.one(element);
}
