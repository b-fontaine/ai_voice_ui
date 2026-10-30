import 'package:flutter_test/flutter_test.dart';
import 'package:testing_backend_fakes/testing_backend_fakes.dart';

import '../support/crashlist_harness.dart';

/// Usage: le serveur émet la liste des crashs dont une ligne n'a pas de libellé
///
/// Données hors contrat (la ligne de rang 3 n'a pas de `label`) : la surface
/// entière montre l'état neutre (RG-10), sans ligne partielle.
Future<void> leServeurEmetLaListeDesCrashsDontUneLigneNaPasDeLibelle(
  WidgetTester tester,
) {
  final items = CrashListHarness.items();
  items[2].remove('label');
  return CrashListHarness.emitUpTo(
    tester,
    SurfaceStage.data,
    value: <String, Object?>{'title': CrashListHarness.title, 'items': items},
  );
}
