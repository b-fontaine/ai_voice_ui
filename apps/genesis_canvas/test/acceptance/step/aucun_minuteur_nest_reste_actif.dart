import 'package:flutter_test/flutter_test.dart';

import '../support/acte4_harness.dart';

/// Usage: aucun minuteur n'est resté actif
///
/// Le banc de test échoue de lui-même si un `Timer` survit à l'arbre démonté
/// (« A Timer is still pending even after the widget tree was disposed ») ;
/// on laisse en plus écouler du temps simulé : un lecteur encore actif
/// planifierait un cadre ou un minuteur.
Future<void> aucunMinuteurNestResteActif(WidgetTester tester) async {
  expect(
    find.byKey(ReplayKeys.play),
    findsNothing,
    reason: 'la page doit être démontée',
  );
  await tester.pump(const Duration(seconds: 30));
  expect(tester.binding.hasScheduledFrame, isFalse);
}
