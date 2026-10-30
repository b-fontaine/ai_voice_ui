import 'package:flutter_test/flutter_test.dart';
import 'package:testing_backend_fakes/testing_backend_fakes.dart';

import '../support/crashlist_harness.dart';

/// Usage: le serveur émet la liste des crashs dont le champ {'items'} est une chaîne
///
/// Données hors contrat (champ au mauvais type) : la surface doit montrer
/// l'état neutre (RG-10), jamais une ligne.
Future<void> leServeurEmetLaListeDesCrashsDontLeChampEstUneChaine(
  WidgetTester tester,
  String field,
) async {
  final value = await CrashListHarness.contractValue(tester);
  await CrashListHarness.emitUpTo(
    tester,
    SurfaceStage.data,
    value: <String, Object?>{'title': value['title'], field: 'cinq crashs'},
  );
}
