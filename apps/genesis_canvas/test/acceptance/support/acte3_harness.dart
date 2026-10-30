import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testing_backend_fakes/testing_backend_fakes.dart';

import '../../support/pump_until.dart';
import 'acte2_harness.dart';
import 'keys.dart';
import 'session_harness.dart';

/// État et aides partagés par les scénarios de l'acte 3 (spec 009).
class Acte3Harness {
  Acte3Harness._();

  static const String actionsSurface = 'actions';

  /// Textes affichés par chacune des quatre surfaces de l'acte 1, relevés
  /// juste avant le clic : « inchangés » se compare à cette photographie.
  static final Map<String, List<String>> textsBefore = <String, List<String>>{};

  /// Texte du statut de décision avant le clic.
  static const String pendingDecision = 'En attente de décision';

  /// Nombre de temps de la Barre d'actions déjà émis dans le scénario.
  static int actionsStagesEmitted = 0;

  static void reset() {
    textsBefore.clear();
    actionsStagesEmitted = 0;
  }

  /// Le speaker dit [phrase] (acte 2 ou correction iOS) ; avec [withActions],
  /// le tour de Livraison crée aussi la Barre d'actions (pdr-0065, D2).
  static Future<void> say(
    WidgetTester tester,
    String phrase, {
    bool withActions = false,
  }) async {
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
        withActions: withActions,
      ),
    );
    await SessionHarness.waitFor(
      tester,
      find.descendant(
        of: find.byKey(AcceptanceKeys.surface('kpi')),
        matching: find.textContaining('· $platform'),
      ),
      'la surface kpi doit afficher « · $platform »',
    );
    await settleReal(tester, duration: const Duration(milliseconds: 100));
  }

  static Finder actionsCell() =>
      find.byKey(AcceptanceKeys.surface(actionsSurface));

  static Finder button(String id) => find.descendant(
    of: actionsCell(),
    matching: find.byKey(AcceptanceKeys.actionButton(id)),
  );

  /// Le bouton de la Barre d'actions portant le libellé [label].
  static Finder buttonLabelled(String label) => find.ancestor(
    of: find.descendant(of: actionsCell(), matching: find.text(label)),
    matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
  );

  /// Les boutons de la Barre d'actions, dans l'ordre du contrat.
  static List<Finder> buttons() => <Finder>[
    for (final id in const <String>['block_release', 'validate_release'])
      button(id),
  ];

  /// `true` si le bouton [finder] est présent et activable.
  static bool isEnabled(WidgetTester tester, Finder finder) {
    final candidates = find.descendant(
      of: finder,
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      matchRoot: true,
    );
    if (candidates.evaluate().isEmpty) return false;
    return tester.widget<ButtonStyleButton>(candidates.first).enabled;
  }

  /// Tous les textes visibles sous la cellule [id], dans l'ordre de l'arbre.
  static List<String> textsOf(WidgetTester tester, String id) => find
      .descendant(
        of: find.byKey(AcceptanceKeys.surface(id)),
        matching: find.byType(Text),
      )
      .evaluate()
      .map(
        (e) =>
            (e.widget as Text).data ??
            (e.widget as Text).textSpan?.toPlainText() ??
            '',
      )
      .toList();

  /// Dernier corps JSON reçu sur `POST /canvas/actions`, décodé.
  static Map<String, Object?>? lastActionBody() {
    final bodies = SessionHarness.backend.canvasActionBodies;
    if (bodies.isEmpty) return null;
    return Map<String, Object?>.from(jsonDecode(bodies.last) as Map);
  }

  /// Avance l'horloge simulée par pas, avec un temps réel entre deux pas, pour
  /// laisser le serveur et les réessais de l'app travailler.
  static Future<void> elapse(
    WidgetTester tester, {
    Duration total = const Duration(seconds: 30),
    Duration step = const Duration(milliseconds: 500),
  }) async {
    var done = Duration.zero;
    while (done < total) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(step);
      done += step;
    }
  }
}
