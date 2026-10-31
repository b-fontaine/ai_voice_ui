import 'package:flutter_test/flutter_test.dart';

import '../support/design_harness.dart';

/// Usage: je note les rectangles des surfaces
Future<void> jeNoteLesRectanglesDesSurfaces(WidgetTester tester) async {
  DesignHarness.noteSurfaces(tester);
  expect(
    DesignHarness.notedSurfaces,
    isNotEmpty,
    reason: 'aucune surface à relever',
  );
}
