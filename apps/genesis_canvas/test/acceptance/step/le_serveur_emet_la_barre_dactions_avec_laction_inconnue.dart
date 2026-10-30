import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: le serveur émet la Barre d'actions avec l'action inconnue {'delete_release'}
///
/// Données hors contrat (identifiant d'action hors de l'ensemble fermé) : la
/// surface doit montrer l'état neutre (RG-10), jamais un bouton.
Future<void> leServeurEmetLaBarreDactionsAvecLactionInconnue(
  WidgetTester tester,
  String action,
) async {
  final session = SessionHarness.backend.lastSessionId!;
  await SessionHarness.onServer(
    tester,
    () => SessionHarness.backend.emitGenesisActions(
      session,
      data: <String, Object?>{
        'title': 'Décision',
        'actions': <Object?>[
          <String, Object?>{
            'id': action,
            'label': 'Supprimer',
            'tone': 'danger',
          },
        ],
      },
    ),
  );
}
