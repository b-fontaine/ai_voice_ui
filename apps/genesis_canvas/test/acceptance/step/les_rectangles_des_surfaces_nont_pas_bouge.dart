import 'package:flutter_test/flutter_test.dart';

import '../support/design_harness.dart';

/// Usage: les rectangles des surfaces n'ont pas bougé
///
/// Les surfaces relevées sont aux mêmes rectangles (S-02) ; une surface
/// arrivée depuis n'est pas comparée.
Future<void> lesRectanglesDesSurfacesNontPasBouge(WidgetTester tester) async {
  expect(
    DesignHarness.movedRects<String>(
      DesignHarness.notedSurfaces,
      DesignHarness.surfaceRects(tester),
    ),
    isNull,
    reason: 'une surface a bougé',
  );
}
