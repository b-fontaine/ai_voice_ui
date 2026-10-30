import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

import '../support/keys.dart';

/// Usage: aucun squelette n'est réapparu
Future<void> aucunSqueletteNestReapparu(WidgetTester tester) async {
  expect(
    find.byType(DsSkeleton),
    findsNothing,
    reason: 'un squelette est visible',
  );
  for (final id in AcceptanceKeys.act1Surfaces) {
    expect(find.byKey(AcceptanceKeys.skeleton(id)), findsNothing);
  }
}
