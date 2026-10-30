import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: le serveur émet un message A2UI vivant
///
/// Un `createSurface` valide d'une surface inconnue de l'app : s'il était
/// appliqué, le panneau du protocole compterait un message de plus.
Future<void> leServeurEmetUnMessageA2uiVivant(WidgetTester tester) async {
  final backend = SessionHarness.backend;
  final session = backend.lastSessionId!;
  await SessionHarness.onServer(tester, () async {
    backend.emit(
      session,
      'a2ui',
      <String, Object?>{
        'version': 'v0.9',
        'createSurface': <String, Object?>{
          'surfaceId': 'vivant',
          'catalogId': backend.catalogId,
        },
      },
      agent: 'Qualité',
      task: 'task_vivant',
    );
  });
}
