import 'package:flutter_test/flutter_test.dart';
import 'package:testing_backend_fakes/testing_backend_fakes.dart';

import '../support/keys.dart';
import '../support/session_harness.dart';

/// Usage: le serveur émet la création des quatre surfaces
///
/// Seulement `createSurface` : le squelette doit précéder les composants.
Future<void> leServeurEmetLaCreationDesQuatreSurfaces(
  WidgetTester tester,
) async {
  final session = SessionHarness.backend.lastSessionId!;
  for (final id in AcceptanceKeys.act1Surfaces) {
    await SessionHarness.onServer(
      tester,
      () => SessionHarness.backend.emitGenesisSurface(
        session,
        id,
        upTo: SurfaceStage.skeleton,
      ),
    );
  }
}
