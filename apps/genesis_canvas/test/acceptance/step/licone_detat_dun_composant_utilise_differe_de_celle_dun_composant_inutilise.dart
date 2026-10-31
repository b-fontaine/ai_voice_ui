import 'package:flutter_test/flutter_test.dart';

import '../support/design_harness.dart';

/// Usage: l'icône d'état d'un composant utilisé diffère de celle d'un composant inutilisé
Future<void> liconeDetatDunComposantUtiliseDiffereDeCelleDunComposantInutilise(
  WidgetTester tester,
) async {
  final used = DesignHarness.shelfIcons['utilisé'];
  final unused = DesignHarness.shelfIcons['inutilisé'];
  expect(used, isNotNull, reason: 'aucune icône relevée pour « utilisé »');
  expect(unused, isNotNull, reason: 'aucune icône relevée pour « inutilisé »');
  expect(used, isNot(unused), reason: 'la même icône pour les deux états');
}
