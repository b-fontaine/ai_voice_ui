import 'package:flutter_test/flutter_test.dart';

import '../support/acte4_harness.dart';

/// Usage: je clique sur Lecture
///
/// Le bouton unique `replay-play` doit afficher « Lecture » et être actif.
Future<void> jeCliqueSurLecture(WidgetTester tester) async {
  await Acte4Harness.press(tester, ReplayKeys.play);
  // Le bouton passe en « Pause » pendant la lecture : on ne le vérifie pas ici
  // (la lecture peut finir dans le même cadre) ; `le bouton de lecture
  // affiche` le fait quand le scénario s'y intéresse.
}
