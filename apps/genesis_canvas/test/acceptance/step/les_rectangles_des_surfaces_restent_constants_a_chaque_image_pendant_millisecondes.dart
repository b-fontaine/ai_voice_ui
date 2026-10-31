import 'package:flutter_test/flutter_test.dart';

import '../support/design_harness.dart';

/// Usage: les rectangles des surfaces restent constants à chaque image pendant {400} millisecondes
///
/// Compare, avant puis après chaque image de 16 ms, les rectangles de
/// `surface-<id>` aux rectangles relevés : une transition (translation,
/// fondu) se joue sous la cellule, jamais sur elle.
Future<void>
lesRectanglesDesSurfacesRestentConstantsAChaqueImagePendantMillisecondes(
  WidgetTester tester,
  num milliseconds,
) async {
  var frame = 0;
  void check() {
    final moved = DesignHarness.movedRects<String>(
      DesignHarness.notedSurfaces,
      DesignHarness.surfaceRects(tester),
    );
    expect(moved, isNull, reason: 'image $frame : une surface a bougé');
    frame++;
  }

  check();
  await DesignHarness.elapse(
    tester,
    Duration(milliseconds: milliseconds.toInt()),
    onFrame: check,
  );
}
