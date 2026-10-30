import 'package:flutter_test/flutter_test.dart';
import 'package:testing_backend_fakes/testing_backend_fakes.dart';

import '../../support/pump_until.dart';
import '../support/acte2_harness.dart';
import '../support/session_harness.dart';
import 'la_surface_affiche.dart';

/// Usage: je dis {'Concentre-toi sur Android et compare avec la 3.3'}
///
/// Le faux backend émet le tour qui répond à la phrase : la phrase, la
/// délégation, le plan des trois agents, leur activité et les seules mises à
/// jour de données (`updateDataModel`) lues dans les exemples du contrat.
/// Phrases connues : l'acte 2 et la correction « Non, plutôt iOS ».
Future<void> jeDis(WidgetTester tester, String phrase) async {
  const act2 = 'Concentre-toi sur Android et compare avec la 3.3';
  const correction = 'Non, plutôt iOS';
  final (followUp, platform) = switch (phrase) {
    act2 => (GenesisFollowUp.act2, 'Android'),
    correction => (GenesisFollowUp.correctionIos, 'iOS'),
    _ => throw ArgumentError('Phrase inconnue du faux backend : $phrase'),
  };
  final session = SessionHarness.backend.lastSessionId!;
  final delegation = 'deleg_${++Acte2Harness.delegations}';
  await SessionHarness.onServer(tester, () async {
    SessionHarness.backend.emitGenesisUserPhrase(
      session,
      phrase,
      delegation: delegation,
    );
  });
  await SessionHarness.onServer(
    tester,
    () => SessionHarness.backend.emitGenesisFollowUp(
      session,
      followUp,
      delegation: delegation,
    ),
  );
  // Les mises à jour arrivent dans l'ordre : le libellé du KPI signale que le
  // tour est appliqué, puis un court temps réel laisse passer les autres.
  await laSurfaceAffiche(tester, 'kpi', '· $platform');
  await settleReal(tester, duration: const Duration(milliseconds: 100));
}
