import 'dart:async';

import 'package:entity_session/entity_session.dart';
import 'package:feature_agent_activity/feature_agent_activity.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:testing_bloc_harness/testing_bloc_harness.dart';

AgentActivityReceived activity(
  String agent,
  String task,
  AgentTaskState state, {
  String? label,
  String? detail,
}) => AgentActivityReceived(
  agent: agent,
  task: task,
  state: state,
  label: label,
  detail: detail,
);

AgentStatus status(
  String agent,
  String task,
  AgentRunState state, {
  String? label,
  String? detail,
}) => AgentStatus(
  agent: agent,
  task: task,
  state: state,
  label: label,
  detail: detail,
);

Future<List<AgentActivityState>> run(List<SessionEvent> events) async {
  final StreamController<SessionEvent> controller =
      StreamController<SessionEvent>();
  return statesAfter(AgentActivityBloc(), (bloc) async {
    bloc.add(AgentActivitySourceSubscribed(controller.stream));
    await Future<void>.delayed(Duration.zero);
    events.forEach(controller.add);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  });
}

PlanReceived plan(List<String> selected, List<String> idle) =>
    PlanReceived(delegation: 'd1', selected: selected, idle: idle);

Matcher rows(List<(String, AgentRunState)> expected) =>
    predicate<AgentActivityState>(
      (s) =>
          s.agents.length == expected.length &&
          [
            for (int i = 0; i < expected.length; i++)
              s.agents[i].agent == expected[i].$1 &&
                  s.agents[i].state == expected[i].$2,
          ].every((b) => b),
      'lignes $expected',
    );

void main() {
  const AgentTaskState working = AgentTaskState.working;
  const AgentTaskState completed = AgentTaskState.completed;
  const AgentTaskState failed = AgentTaskState.failed;

  test('état initial vide, aucun agent en cours', () {
    const AgentActivityState s = AgentActivityState.empty();
    expect(s.agents, isEmpty);
    expect(s.anyWorking, isFalse);
    expect(s, const AgentActivityState.empty());
  });

  test('working puis completed met à jour la ligne', () async {
    final states = await run([
      activity('release', 't1', working, label: 'Analyse'),
      activity('release', 't1', completed, label: 'Analyse'),
    ]);
    expect(states, [
      AgentActivityState([
        status('release', 't1', AgentRunState.working, label: 'Analyse'),
      ]),
      AgentActivityState([
        status('release', 't1', AgentRunState.completed, label: 'Analyse'),
      ]),
    ]);
  });

  test('failed reprend detail', () async {
    final states = await run([activity('a', 't', failed, detail: 'timeout')]);
    expect(
      states.single.agents.single,
      status('a', 't', AgentRunState.failed, detail: 'timeout'),
    );
  });

  test('deux agents dans l\'ordre d\'apparition', () async {
    final states = await run([
      activity('a', 't1', working),
      activity('b', 't2', working),
      activity('a', 't1', completed),
    ]);
    expect(states.last.agents.map((s) => s.agent), ['a', 'b']);
    expect(states.last.agents.map((s) => s.state), [
      AgentRunState.completed,
      AgentRunState.working,
    ]);
  });

  test('même agent, nouvelle tâche : la ligne est remplacée', () async {
    final states = await run([
      activity('a', 't1', completed),
      activity('a', 't2', working),
    ]);
    expect(states.last.agents, [status('a', 't2', AgentRunState.working)]);
  });

  test('completed sans working préalable crée la ligne', () async {
    final states = await run([activity('a', 't', completed)]);
    expect(states.single.agents, [status('a', 't', AgentRunState.completed)]);
  });

  test('closed : working devient interrupted, le reste est intact', () async {
    final states = await run([
      activity('a', 't', working),
      activity('b', 't', completed),
      activity('c', 't', failed, detail: 'x'),
      const SessionStateChanged(state: SessionState.closed),
    ]);
    expect(states.last.agents, [
      status('a', 't', AgentRunState.interrupted),
      status('b', 't', AgentRunState.completed),
      status('c', 't', AgentRunState.failed, detail: 'x'),
    ]);
    expect(states.last.anyWorking, isFalse);
  });

  test('ChannelLost : working devient interrupted', () async {
    final states = await run([
      activity('a', 't', working),
      activity('b', 't', completed),
      const ChannelLost('coupure'),
    ]);
    expect(states.last.agents, [
      status('a', 't', AgentRunState.interrupted),
      status('b', 't', AgentRunState.completed),
    ]);
  });

  test('connecting vide la liste', () async {
    final states = await run([
      activity('a', 't', working),
      const SessionStateChanged(state: SessionState.connecting),
    ]);
    expect(states.last, const AgentActivityState.empty());
  });

  test(
    'événements étrangers ignorés, pas de réémission d\'un état égal',
    () async {
      final states = await run([
        activity('a', 't', working),
        const SessionStateChanged(state: SessionState.active),
        const OrbLevelChanged(0.5),
        const SessionStateChanged(state: SessionState.closed),
        const SessionStateChanged(state: SessionState.closed),
      ]);
      expect(states.map((s) => s.agents.single.state), [
        AgentRunState.working,
        AgentRunState.interrupted,
      ]);
    },
  );

  test('anyWorking', () {
    expect(
      AgentActivityState([status('a', 't', AgentRunState.working)]).anyWorking,
      isTrue,
    );
    expect(
      AgentActivityState([status('a', 't', AgentRunState.failed)]).anyWorking,
      isFalse,
    );
  });

  test('anyBusy : travail en cours ou agent retenu en attente', () {
    bool busy(AgentRunState state) =>
        AgentActivityState([status('a', 't', state)]).anyBusy;
    expect(busy(AgentRunState.working), isTrue);
    expect(busy(AgentRunState.pending), isTrue);
    expect(busy(AgentRunState.completed), isFalse);
    expect(busy(AgentRunState.failed), isFalse);
    expect(busy(AgentRunState.interrupted), isFalse);
    // La ligne de l'orchestrateur reste après le plan : elle n'est pas
    // du travail en cours.
    expect(busy(AgentRunState.orchestrating), isFalse);
    expect(const AgentActivityState.empty().anyBusy, isFalse);
    // `anyWorking` ne couvre pas `pending` (orbe « réflexion »).
    expect(
      AgentActivityState([status('a', 't', AgentRunState.pending)]).anyWorking,
      isFalse,
    );
  });

  test('la liste exposée n\'est pas modifiable', () {
    final s = AgentActivityState([status('a', 't', AgentRunState.working)]);
    expect(
      () => s.agents.add(status('b', 't', AgentRunState.working)),
      throwsUnsupportedError,
    );
  });

  test('une erreur du flux est ignorée', () async {
    final controller = StreamController<SessionEvent>();
    final states = await statesAfter(AgentActivityBloc(), (bloc) async {
      bloc.add(AgentActivitySourceSubscribed(controller.stream));
      await Future<void>.delayed(Duration.zero);
      controller.addError(StateError('boom'));
      await Future<void>.delayed(Duration.zero);
    });
    expect(states, isEmpty);
  });

  test('une seconde souscription annule la première', () async {
    final first = StreamController<SessionEvent>();
    final second = StreamController<SessionEvent>();
    final states = await statesAfter(AgentActivityBloc(), (bloc) async {
      bloc.add(AgentActivitySourceSubscribed(first.stream));
      await Future<void>.delayed(Duration.zero);
      bloc.add(AgentActivitySourceSubscribed(second.stream));
      await Future<void>.delayed(Duration.zero);
      expect(first.hasListener, isFalse);
      first.add(activity('old', 't', working));
      second.add(activity('new', 't', working));
      await Future<void>.delayed(Duration.zero);
    });
    expect(states.single.agents.single.agent, 'new');
  });

  group('plan (FR-03, RG-29, pdr-0013)', () {
    const String orch = AgentActivityState.orchestratorName;

    test('le nom d\'affichage de l\'orchestrateur est « Orchestrateur »', () {
      expect(orch, 'Orchestrateur');
    });

    test(
      'rail : orchestrateur, puis selected dans l\'ordre, puis idle',
      () async {
        final states = await run([
          plan(['Voix du client', 'Qualité'], ['Livraison']),
        ]);
        expect(
          states.last,
          rows([
            (orch, AgentRunState.orchestrating),
            ('Voix du client', AgentRunState.pending),
            ('Qualité', AgentRunState.pending),
            ('Livraison', AgentRunState.idle),
          ]),
        );
        expect(states.last.noAgentSelected, isFalse);
      },
    );

    test(
      'un agent retenu passe de pending à working, un idle reste en veille',
      () async {
        final states = await run([
          plan(['Voix du client'], ['Qualité', 'Livraison']),
          activity('Voix du client', 't', working, label: 'Analyse'),
        ]);
        expect(
          states.last,
          rows([
            (orch, AgentRunState.orchestrating),
            ('Voix du client', AgentRunState.working),
            ('Qualité', AgentRunState.idle),
            ('Livraison', AgentRunState.idle),
          ]),
        );
        expect(states.last.anyWorking, isTrue);
      },
    );

    test('plan vide : noAgentSelected et tous en veille', () async {
      final states = await run([
        plan([], ['Qualité', 'Livraison']),
      ]);
      expect(states.last.noAgentSelected, isTrue);
      expect(
        states.last,
        rows([
          (orch, AgentRunState.orchestrating),
          ('Qualité', AgentRunState.idle),
          ('Livraison', AgentRunState.idle),
        ]),
      );
    });

    test('le dernier plan remplace le précédent', () async {
      final states = await run([
        plan(['A'], ['B']),
        activity('A', 't', completed),
        plan(['B'], ['A']),
      ]);
      expect(
        states.last,
        rows([
          (orch, AgentRunState.orchestrating),
          ('B', AgentRunState.pending),
          ('A', AgentRunState.idle),
        ]),
      );
      expect(states.last.noAgentSelected, isFalse);
    });

    test('activité d\'un agent inconnu du plan : ajouté en fin', () async {
      final states = await run([
        plan(['A'], []),
        activity('Z', 't', working),
      ]);
      expect(
        states.last,
        rows([
          (orch, AgentRunState.orchestrating),
          ('A', AgentRunState.pending),
          ('Z', AgentRunState.working),
        ]),
      );
    });

    test('rejected garde le détail « hors périmètre »', () async {
      final states = await run([
        plan(['A'], []),
        activity('A', 't', AgentTaskState.rejected, detail: 'hors périmètre'),
      ]);
      final a = states.last.agents.last;
      expect(a.state, AgentRunState.rejected);
      expect(a.detail, 'hors périmètre');
      expect(states.last.anyWorking, isFalse);
    });

    test(
      'fin de session : working et pending deviennent interrupted, idle intact',
      () async {
        final states = await run([
          plan(['A', 'B', 'C'], ['D']),
          activity('A', 't', working),
          activity('B', 't', completed),
          const ChannelLost('x'),
        ]);
        expect(
          states.last,
          rows([
            (orch, AgentRunState.orchestrating),
            ('A', AgentRunState.interrupted),
            ('B', AgentRunState.completed),
            ('C', AgentRunState.interrupted),
            ('D', AgentRunState.idle),
          ]),
        );
      },
    );

    test('connecting vide la liste et le drapeau', () async {
      final states = await run([
        plan([], ['A']),
        const SessionStateChanged(state: SessionState.connecting),
      ]);
      expect(states.last, const AgentActivityState.empty());
      expect(states.last.noAgentSelected, isFalse);
    });

    test('un plan identique n\'est pas réémis', () async {
      final states = await run([
        plan(['A'], []),
        plan(['A'], []),
      ]);
      expect(states, hasLength(1));
    });

    test('AgentActivityReset : retour à l\'état initial vide', () async {
      final states = await statesAfter(AgentActivityBloc(), (bloc) async {
        final c = StreamController<SessionEvent>();
        bloc.add(AgentActivitySourceSubscribed(c.stream));
        await Future<void>.delayed(Duration.zero);
        c.add(plan([], ['A']));
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        bloc.add(const AgentActivityReset());
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
      });
      expect(states.last, const AgentActivityState.empty());
      expect(states, hasLength(2));
    });

    test('égalité : le drapeau noAgentSelected compte', () {
      expect(
        AgentActivityState(const [], noAgentSelected: true),
        isNot(AgentActivityState(const [])),
      );
    });
  });
}
