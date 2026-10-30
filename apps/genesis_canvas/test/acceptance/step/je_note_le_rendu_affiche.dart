import 'package:flutter_test/flutter_test.dart';

import '../support/acte4_harness.dart';

/// Usage: je note le rendu affiché
Future<void> jeNoteLeRenduAffiche(WidgetTester tester) async {
  await tester.pump();
  Acte4Harness.notedRender = Acte4Harness.snapshot(tester);
}
