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
}
