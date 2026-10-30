import 'package:flutter_test/flutter_test.dart';
import 'package:testing_backend_fakes/testing_backend_fakes.dart';

import '../support/crashlist_harness.dart';

/// Usage: le serveur émet la liste des crashs jusqu'au temps {'data'}
///
/// Surface `crashes` (composant `CrashList`, données `/crashes`) ; temps :
/// `skeleton` (createSurface), `components` (updateComponents) ou `data`
/// (updateDataModel). Les temps déjà émis ne sont pas renvoyés.
Future<void> leServeurEmetLaListeDesCrashsJusquauTemps(
  WidgetTester tester,
  String stage,
) async {
  final upTo = SurfaceStage.values.firstWhere(
    (s) => s.name == stage,
    orElse: () => fail('temps de surface inconnu : $stage'),
  );
  await CrashListHarness.emitUpTo(tester, upTo);
}
