import 'package:flutter_test/flutter_test.dart';

import '../support/keys.dart';

/// Usage: la surface {'kpi'} ne porte pas le contour pointillé
Future<void> laSurfaceNePortePasLeContourPointille(
  WidgetTester tester,
  String surface,
) async {
  expect(
    find.byKey(AcceptanceKeys.surface(surface)),
    findsOneWidget,
    reason: 'la surface $surface doit exister',
  );
  expect(find.byKey(AcceptanceKeys.highlight(surface)), findsNothing);
}
