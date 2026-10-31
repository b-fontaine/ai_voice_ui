import 'package:flutter_test/flutter_test.dart';

import '../support/design_harness.dart';

/// Usage: je note les rectangles des zones de l'écran
///
/// Rail, canevas, étagère et panneau du protocole.
Future<void> jeNoteLesRectanglesDesZonesDeLecran(WidgetTester tester) async {
  DesignHarness.noteZones(tester);
}
