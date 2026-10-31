import 'package:flutter_test/flutter_test.dart';
import 'package:testing_real_fonts/testing_real_fonts.dart';

import '../support/design_harness.dart';

/// Titre de la courbe dans les exemples du contrat.
const trendTitle = 'Taux de crash du jour';

/// Usage: le titre de la courbe n'est pas tronqué
Future<void> leTitreDeLaCourbeNestPasTronque(WidgetTester tester) async {
  final title = find.descendant(
    of: DesignHarness.surface('trend'),
    matching: find.text(trendTitle),
  );
  expect(title, findsOneWidget, reason: 'titre « $trendTitle » absent');
  expect(
    paragraphsTruncated(tester, root: title),
    isEmpty,
    reason: 'le titre de la courbe est tronqué',
  );
}
