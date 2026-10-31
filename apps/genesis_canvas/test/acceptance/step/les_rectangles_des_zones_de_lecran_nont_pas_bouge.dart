import 'package:flutter/painting.dart' show Rect;
import 'package:flutter_test/flutter_test.dart';

import '../support/design_harness.dart';

/// Usage: les rectangles des zones de l'écran n'ont pas bougé
Future<void> lesRectanglesDesZonesDeLecranNontPasBouge(
  WidgetTester tester,
) async {
  expect(
    DesignHarness.notedZones,
    isNotEmpty,
    reason: "les zones de l'écran n'ont pas été relevées",
  );
  final now = <Object, Rect>{
    for (final key in DesignHarness.zoneKeys)
      key: DesignHarness.rectOf(tester, key),
  };
  expect(
    DesignHarness.movedRects<Object>(DesignHarness.notedZones, now),
    isNull,
    reason: "une zone de l'écran a bougé",
  );
}
