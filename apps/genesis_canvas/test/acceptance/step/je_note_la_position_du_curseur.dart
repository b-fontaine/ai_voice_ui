import 'package:flutter_test/flutter_test.dart';

import '../support/acte4_harness.dart';

/// Usage: je note la position du curseur
Future<void> jeNoteLaPositionDuCurseur(WidgetTester tester) async {
  Acte4Harness.notedPosition = Acte4Harness.position(tester);
}
