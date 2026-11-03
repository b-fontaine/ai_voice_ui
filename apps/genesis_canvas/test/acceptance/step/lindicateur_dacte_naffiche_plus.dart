import 'package:flutter_test/flutter_test.dart';

import '../../support/act_indicator_finder.dart';
import '../support/keys.dart';

/// Usage: l'indicateur d'acte n'affiche plus {'Rejeu'}
Future<void> lindicateurDacteNaffichePlus(
  WidgetTester tester,
  String text,
) async {
  await tester.pump();
  final indicator = find.byKey(AcceptanceKeys.actIndicator);
  expect(indicator, findsOneWidget, reason: 'act-indicator absent');
  expect(
    findActIndicatorLabel(text),
    findsNothing,
    reason: "l'indicateur d'acte affiche encore « $text »",
  );
}
