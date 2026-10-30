import 'package:flutter_test/flutter_test.dart';

import '../support/keys.dart';
import '../support/session_harness.dart';

/// Usage: la surface {'trend'} porte le contour pointillé
Future<void> laSurfacePorteLeContourPointille(
  WidgetTester tester,
  String surface,
) async {
  await SessionHarness.waitFor(
    tester,
    find.byKey(AcceptanceKeys.highlight(surface)),
    'la surface $surface doit porter le contour pointillé (highlight-$surface)',
  );
  expect(find.byKey(AcceptanceKeys.surface(surface)), findsOneWidget);
}
