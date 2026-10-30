import 'package:flutter_test/flutter_test.dart';

import '../support/keys.dart';

/// Usage: aucun squelette n'est visible pour la surface {'actions'}
Future<void> aucunSqueletteNestVisiblePourLaSurface(
  WidgetTester tester,
  String surface,
) async {
  expect(
    find.byKey(AcceptanceKeys.skeleton(surface)),
    findsNothing,
    reason: 'le squelette de la surface $surface est encore visible',
  );
}
