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

void main() {
  late AgentActivityBloc bloc;
  late StreamController<SessionEvent> events;

  // Créés dans la zone du test (FakeAsync) : sinon les microtâches du Bloc
  // échappent à `pump`.
  void testWidgets(
    String description,
    Future<void> Function(WidgetTester tester) body,
  ) => flutter_test.testWidgets(description, (tester) async {
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
          child: const AgentsRail(),
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
    expect(find.byWidgetPredicate((w) => w is Text), findsNothing);
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
}
