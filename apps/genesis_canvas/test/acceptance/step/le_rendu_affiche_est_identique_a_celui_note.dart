import 'package:flutter_test/flutter_test.dart';

import '../support/acte4_harness.dart';

/// Usage: le rendu affiché est identique à celui noté
///
/// Surfaces (textes, phases, contour du message en cours), moteurs de rendu,
/// étagère et panneau du protocole, hors horodatage.
Future<void> leRenduAfficheEstIdentiqueACeluiNote(WidgetTester tester) async {
  await tester.pump();
  expect(Acte4Harness.snapshot(tester), Acte4Harness.notedRender);
}
