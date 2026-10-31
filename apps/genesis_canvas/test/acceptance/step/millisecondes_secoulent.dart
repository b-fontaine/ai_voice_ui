import 'package:flutter_test/flutter_test.dart';

import '../support/design_harness.dart';

/// Usage: {120} millisecondes s'écoulent
///
/// Temps simulé du test, par images de 16 ms (jamais `pumpAndSettle` : un
/// minuteur périodique ne s'arrête pas).
Future<void> millisecondesSecoulent(WidgetTester tester, num milliseconds) =>
    DesignHarness.elapse(tester, Duration(milliseconds: milliseconds.toInt()));
