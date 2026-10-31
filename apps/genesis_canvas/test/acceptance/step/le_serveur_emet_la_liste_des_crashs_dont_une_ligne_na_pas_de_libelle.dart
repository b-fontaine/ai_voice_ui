import 'package:flutter_test/flutter_test.dart';
import 'package:testing_backend_fakes/testing_backend_fakes.dart';

import '../support/crashlist_harness.dart';

/// Usage: le serveur émet la liste des crashs dont une ligne n'a pas de libellé
///
/// Données hors contrat (la ligne de rang 3 n'a pas de `label`) : la surface
/// entière montre l'état neutre (RG-10), sans ligne partielle.
Future<void> leServeurEmetLaListeDesCrashsDontUneLigneNaPasDeLibelle(
  WidgetTester tester,
) async {
  final value = await CrashListHarness.contractValue(tester);
  ((value['items']! as List<Object?>)[2]! as Map<String, Object?>).remove(
    'label',
  );
  await CrashListHarness.emitUpTo(tester, SurfaceStage.data, value: value);
}
