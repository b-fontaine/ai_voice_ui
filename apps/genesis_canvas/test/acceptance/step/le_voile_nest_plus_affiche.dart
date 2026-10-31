import 'package:flutter_test/flutter_test.dart';

/// Usage: le voile {'Micro coupé'} n'est plus affiché
Future<void> leVoileNestPlusAffiche(WidgetTester tester, String label) async {
  await tester.pump();
  expect(
    find.text(label),
    findsNothing,
    reason: 'le voile « $label » est resté affiché',
  );
}
