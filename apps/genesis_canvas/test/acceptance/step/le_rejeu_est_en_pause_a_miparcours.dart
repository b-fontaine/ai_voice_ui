import 'package:flutter_test/flutter_test.dart';

import '../support/acte4_harness.dart';
import 'je_clique_sur_lecture.dart';
import 'je_clique_sur_pause.dart';
import 'je_place_le_curseur_au_milieu.dart';

/// Usage: le rejeu est en pause à mi-parcours
///
/// Lecture, un peu de temps simulé, Pause, curseur au milieu : le rejeu est
/// actif (`ReplayActive`) et toutes les commandes sont construites. Le panneau
/// du protocole est alors encore replié, ce qui laisse atteindre le curseur.
Future<void> leRejeuEstEnPauseAMiparcours(WidgetTester tester) async {
  await jeCliqueSurLecture(tester);
  await Acte4Harness.elapse(tester, Acte4Harness.seconds(2.5));
  await jeCliqueSurPause(tester);
  await jePlaceLeCurseurAuMilieu(tester);
  final position = Acte4Harness.position(tester);
  expect(
    position,
    inInclusiveRange(10, 90),
    reason: 'le rejeu doit être à mi-parcours (position $position %)',
  );
}
