import 'package:flutter_test/flutter_test.dart';
import 'package:testing_backend_fakes/testing_backend_fakes.dart';

import '../support/keys.dart';
import '../support/session_harness.dart';

/// Usage: le serveur émet les données des quatre surfaces
Future<void> leServeurEmetLesDonneesDesQuatreSurfaces(
  WidgetTester tester,
) async {
  final session = SessionHarness.backend.lastSessionId!;
  for (final id in AcceptanceKeys.act1Surfaces) {
    await SessionHarness.onServer(
      tester,
      () => SessionHarness.backend.emitGenesisSurface(
        session,
        id,
        from: SurfaceStage.data,
        upTo: SurfaceStage.data,
      ),
    );
  }
}
