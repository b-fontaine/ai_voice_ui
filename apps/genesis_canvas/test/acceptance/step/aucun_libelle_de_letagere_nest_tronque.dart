import 'package:flutter_test/flutter_test.dart';
import 'package:testing_real_fonts/testing_real_fonts.dart';

import '../support/keys.dart';

/// Usage: aucun libellé de l'étagère n'est tronqué
Future<void> aucunLibelleDeLetagereNestTronque(WidgetTester tester) async {
  final shelf = find.byKey(AcceptanceKeys.catalogShelf);
  expect(shelf, findsOneWidget, reason: "l'étagère est absente");
  expect(
    paragraphsTruncated(tester, root: shelf),
    isEmpty,
    reason: "libellés tronqués dans l'étagère",
  );
}
