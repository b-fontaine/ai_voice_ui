import 'dart:async';

import 'package:entity_session/entity_session.dart' hide AgentActivityState;
import 'package:entity_session/entity_session.dart'
    as entity
    show AgentActivityState;
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
        state: entity.AgentActivityState.working,
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
        state: entity.AgentActivityState.completed,
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
        state: entity.AgentActivityState.failed,
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
        state: entity.AgentActivityState.working,
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
        state: entity.AgentActivityState.working,
      ),
    );
    await emit(
      tester,
      const AgentActivityReceived(
        agent: 'Risques',
        task: 'b',
        state: entity.AgentActivityState.working,
      ),
    );

    expect(row('Qualité'), findsOneWidget);
    expect(row('Risques'), findsOneWidget);
  });
}
