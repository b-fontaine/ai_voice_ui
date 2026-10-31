import 'dart:async';

import 'package:entity_session/entity_session.dart';
import 'package:feature_agent_activity/feature_agent_activity.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart' hide testWidgets;
import 'package:flutter_test/flutter_test.dart'
    as flutter_test
    show testWidgets;
import 'package:genesis_canvas/widgets/agents_rail/agents_rail.dart';
import 'package:shared_design_system/shared_design_system.dart';
import 'package:testing_real_fonts/testing_real_fonts.dart';

import '../support/paragraphs.dart';

void main() {
  late AgentActivityBloc bloc;
  late StreamController<SessionEvent> events;

  // Créés dans la zone du test (FakeAsync) : sinon les microtâches du Bloc
  // échappent à `pump`.
  void testWidgets(
    String description,
    Future<void> Function(WidgetTester tester) body,
  ) => flutter_test.testWidgets(description, (tester) async {
    // Écran de la démo : le rail dispose de 1872 px (1920 - 2 × 24).
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    bloc = AgentActivityBloc();
    events = StreamController<SessionEvent>.broadcast();
    await body(tester);
    // Démontage puis fermeture, vidée par `pump` (zone FakeAsync).
    await tester.pumpWidget(const SizedBox());
    unawaited(events.close());
    unawaited(bloc.close());
    await tester.pump();
  });

  Future<void> pumpRail(WidgetTester tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: BlocProvider<AgentActivityBloc>.value(
          value: bloc,
          child: const Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 1872, height: 96, child: AgentsRail()),
          ),
        ),
      ),
    );
    bloc.add(AgentActivitySourceSubscribed(events.stream));
    await tester.pump();
  }

  Future<void> emit(WidgetTester tester, SessionEvent event) async {
    events.add(event);
    await tester.pump();
    await tester.pump();
  }

  Finder row(String agent) => find.byKey(Key('agent-$agent'));

  testWidgets('le rail porte la clé agents-rail et reste vide sans agent', (
    tester,
  ) async {
    await pumpRail(tester);

    expect(find.byKey(const Key('agents-rail')), findsOneWidget);
    // Seul le repère de zone est affiché ; aucune tuile.
    expect(find.text('AGENTS A2A'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is Text), findsOneWidget);
  });

  testWidgets(
    'le rail fait 96 px de haut et toute la largeur, vide ou rempli',
    (tester) async {
      await pumpRail(tester);
      final Size empty = tester.getSize(find.byKey(const Key('agents-rail')));
      expect(empty, const Size(1872, 96));

      await emit(
        tester,
        PlanReceived(
          delegation: 'd1',
          selected: const <String>['Qualité', 'Voix du client'],
          idle: const <String>['Livraison'],
        ),
      );
      expect(tester.getSize(find.byKey(const Key('agents-rail'))), empty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('tuiles à droite du repère, dans l\'ordre, sur une rangée', (
    tester,
  ) async {
    await pumpRail(tester);
    await emit(
      tester,
      PlanReceived(
        delegation: 'd1',
        selected: const <String>['Qualité'],
        idle: const <String>['Livraison'],
      ),
    );
    final Rect title = tester.getRect(find.text('AGENTS A2A'));
    final List<Rect> tiles = <Rect>[
      for (final String n in <String>['Orchestrateur', 'Qualité', 'Livraison'])
        tester.getRect(row(n)),
    ];
    for (final Rect t in tiles) {
      expect(t.left, greaterThanOrEqualTo(title.right));
      expect(t.top, tiles.first.top);
      expect(t.height, lessThanOrEqualTo(96));
    }
    expect(tiles[1].left, greaterThanOrEqualTo(tiles[0].right));
    expect(tiles[2].left, greaterThanOrEqualTo(tiles[1].right));
  });

  testWidgets('cinq tuiles au pire cas : polices réelles, rien de tronqué '
      'sauf la tâche, aucun débordement', (tester) async {
    await loadRealFonts(alsoAs: const <String>['Roboto']);
    await pumpRail(tester);
    await emit(
      tester,
      PlanReceived(
        delegation: 'd1',
        selected: const <String>['Voix du client', 'Qualité', 'Livraison'],
        idle: const <String>['Conformité'],
      ),
    );
    await emit(
      tester,
      const AgentActivityReceived(
        agent: 'Voix du client',
        task: 't1',
        state: AgentTaskState.working,
        label: 'Analyse des avis des utilisateurs',
      ),
    );
    await emit(
      tester,
      const AgentActivityReceived(
        agent: 'Qualité',
        task: 't2',
        state: AgentTaskState.rejected,
        detail: 'hors périmètre',
      ),
    );

    expect(find.byKey(const Key('agent-Orchestrateur')), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(paragraphsBelowMinimum(tester), isEmpty);
    // Le nom, l'état et le repère ne sont jamais tronqués.
    final List<String> truncated = paragraphsTruncated(tester);
    expect(truncated, isNot(contains('« Voix du client »')));
    expect(truncated, isNot(contains('« hors périmètre »')));
    expect(truncated, isNot(contains('« en cours »')));
    expect(truncated, isNot(contains('« Orchestrateur »')));
    expect(truncated, isNot(contains('« AGENTS A2A »')));
    // La tâche reste affichée (même abrégée) : son texte est dans l'arbre.
    expect(
      find.descendant(
        of: row('Voix du client'),
        matching: find.textContaining('Analyse des avis', findRichText: true),
      ),
      findsOneWidget,
    );
    // Chaque tuile reste dans la largeur du rail.
    for (final String n in <String>[
      'Orchestrateur',
      'Voix du client',
      'Qualité',
      'Livraison',
      'Conformité',
    ]) {
      final Rect r = tester.getRect(row(n));
      expect(r.right, lessThanOrEqualTo(1872), reason: n);
      expect(r.height, lessThanOrEqualTo(96), reason: n);
    }
  });

  testWidgets('un agent au travail puis terminé', (tester) async {
    await pumpRail(tester);

    await emit(
      tester,
      const AgentActivityReceived(
        agent: 'Qualité',
        task: 'analyse',
        state: AgentTaskState.working,
        label: 'Analyse de la release',
      ),
    );
    expect(
      find.descendant(of: row('Qualité'), matching: find.text('en cours')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row('Qualité'), matching: find.text('Qualité')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: row('Qualité'),
        matching: find.text('Analyse de la release'),
      ),
      findsOneWidget,
    );

    await emit(
      tester,
      const AgentActivityReceived(
        agent: 'Qualité',
        task: 'analyse',
        state: AgentTaskState.completed,
      ),
    );
    expect(
      find.descendant(of: row('Qualité'), matching: find.text('terminé')),
      findsOneWidget,
    );
    expect(find.text('en cours'), findsNothing);
  });

  testWidgets(
    'la couleur du point vient des jetons du thème de scène (RG-09)',
    (tester) async {
      await pumpRail(tester);
      const theme = SceneTheme.dark();
      Color? dot(String agent) => tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: row(agent),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((b) => (b.decoration as BoxDecoration).color)
          .first;

      await emit(
        tester,
        const AgentActivityReceived(
          agent: 'Qualité',
          task: 'analyse',
          state: AgentTaskState.working,
        ),
      );
      expect(dot('Qualité'), theme.agentWorking);

      await emit(
        tester,
        const AgentActivityReceived(
          agent: 'Qualité',
          task: 'analyse',
          state: AgentTaskState.completed,
        ),
      );
      expect(dot('Qualité'), theme.okForeground);
      // L'état reste dit en toutes lettres : la couleur n'est qu'un renfort.
      expect(
        find.descendant(of: row('Qualité'), matching: find.text('terminé')),
        findsOneWidget,
      );
    },
  );

  testWidgets('un échec affiche son détail', (tester) async {
    await pumpRail(tester);

    await emit(
      tester,
      const AgentActivityReceived(
        agent: 'Risques',
        task: 'scan',
        state: AgentTaskState.failed,
        detail: 'délai dépassé',
      ),
    );

    final texts = find.descendant(
      of: row('Risques'),
      matching: find.byType(Text),
    );
    expect(
      tester.widgetList<Text>(texts).map((t) => t.data),
      contains('échec'),
    );
    expect(
      find.descendant(
        of: row('Risques'),
        matching: find.textContaining('délai dépassé'),
      ),
      findsOneWidget,
    );
  });

  testWidgets("fin de session : l'agent au travail devient interrompu", (
    tester,
  ) async {
    await pumpRail(tester);
    await emit(
      tester,
      const AgentActivityReceived(
        agent: 'Qualité',
        task: 'analyse',
        state: AgentTaskState.working,
      ),
    );

    await emit(tester, const ChannelLost('connection_lost'));

    expect(
      find.descendant(of: row('Qualité'), matching: find.text('interrompu')),
      findsOneWidget,
    );
  });

  testWidgets('deux agents : deux lignes', (tester) async {
    await pumpRail(tester);
    await emit(
      tester,
      const AgentActivityReceived(
        agent: 'Qualité',
        task: 'a',
        state: AgentTaskState.working,
      ),
    );
    await emit(
      tester,
      const AgentActivityReceived(
        agent: 'Risques',
        task: 'b',
        state: AgentTaskState.working,
      ),
    );

    expect(row('Qualité'), findsOneWidget);
    expect(row('Risques'), findsOneWidget);
  });

  testWidgets(
    'un plan affiche orchestrateur, agent retenu et agents en veille',
    (tester) async {
      await pumpRail(tester);
      await emit(
        tester,
        PlanReceived(
          delegation: 'd1',
          selected: const <String>['Voix du client'],
          idle: const <String>['Qualité', 'Livraison'],
        ),
      );
      expect(row('Orchestrateur'), findsOneWidget);
      expect(
        find.descendant(
          of: row('Voix du client'),
          matching: find.text('en attente'),
        ),
        findsOneWidget,
      );
      for (final String name in <String>['Qualité', 'Livraison']) {
        expect(
          find.descendant(of: row(name), matching: find.text('en veille')),
          findsOneWidget,
        );
      }
      expect(find.text('aucun agent retenu'), findsNothing);

      await emit(
        tester,
        const AgentActivityReceived(
          agent: 'Voix du client',
          task: 't',
          state: AgentTaskState.working,
        ),
      );
      expect(
        find.descendant(
          of: row('Voix du client'),
          matching: find.text('en cours'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('un plan vide affiche « aucun agent retenu »', (tester) async {
    await pumpRail(tester);
    await emit(
      tester,
      PlanReceived(
        delegation: 'd',
        selected: const <String>[],
        idle: const <String>['Qualité'],
      ),
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('agents-rail')),
        matching: find.text('aucun agent retenu'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('agents-none')), findsOneWidget);
  });

  testWidgets('un agent qui refuse est « hors périmètre » avec son détail', (
    tester,
  ) async {
    await pumpRail(tester);
    await emit(
      tester,
      PlanReceived(
        delegation: 'd',
        selected: const <String>['Qualité'],
        idle: const <String>[],
      ),
    );
    await emit(
      tester,
      const AgentActivityReceived(
        agent: 'Qualité',
        task: 't',
        state: AgentTaskState.rejected,
        detail: 'hors périmètre',
      ),
    );
    expect(
      find.descendant(
        of: row('Qualité'),
        matching: find.text('hors périmètre'),
      ),
      findsOneWidget, // le détail identique au libellé n'est pas répété
    );
  });

  testWidgets('tout le texte du rail fait au moins 24 px et reste lisible', (
    tester,
  ) async {
    await pumpRail(tester);
    await emit(
      tester,
      PlanReceived(
        delegation: 'd1',
        selected: const <String>['Qualité', 'Voix du client'],
        idle: const <String>['Livraison'],
      ),
    );
    await emit(
      tester,
      const AgentActivityReceived(
        agent: 'Qualité',
        task: 't1',
        state: AgentTaskState.working,
        label: 'Analyse de la release',
      ),
    );

    expect(paragraphsBelowMinimum(tester), isEmpty);
    const theme = SceneTheme.dark();
    final Text name = tester.widget<Text>(
      find.descendant(of: row('Qualité'), matching: find.text('Qualité')),
    );
    expect(name.style?.color, theme.textPrimary);
  });

  testWidgets('un nom d\'agent de 80 caractères s\'abrège sans déborder', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpRail(tester);
    final String name = 'Agent${' très long'.padRight(75, 'x')}';
    expect(name, hasLength(80));
    await emit(
      tester,
      AgentActivityReceived(
        agent: name,
        task: 't1',
        state: AgentTaskState.working,
        label: 'Analyse de la release',
      ),
    );

    expect(tester.takeException(), isNull);
    final Text shown = tester.widget<Text>(
      find.descendant(of: row(name), matching: find.text(name)),
    );
    expect(shown.overflow, TextOverflow.ellipsis);
    expect(shown.maxLines, 1);
    expect(paragraphsBelowMinimum(tester), isEmpty);
  });

  testWidgets('un détail très long s\'abrège sans déborder', (tester) async {
    tester.view.physicalSize = const Size(900, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpRail(tester);
    await emit(
      tester,
      AgentActivityReceived(
        agent: 'Qualité',
        task: 't1',
        state: AgentTaskState.failed,
        label: 'Analyse de la release ${'très longue ' * 20}',
        detail: 'délai dépassé ${'encore ' * 30}',
      ),
    );

    expect(tester.takeException(), isNull);
    expect(row('Qualité'), findsOneWidget);
  });
}
