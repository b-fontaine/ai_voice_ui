import 'dart:async';

import 'package:a2ui_core/a2ui_core.dart' as a2ui;
import 'package:entity_catalog/entity_catalog.dart';
import 'package:entity_session/entity_session.dart';
import 'package:feature_canvas/feature_canvas.dart';
import 'package:flutter_test/flutter_test.dart';

const String _catalog = GenesisContract.defaultCatalogId;

Map<String, Object?> _create(String id, {String catalogId = _catalog}) =>
    <String, Object?>{
      'version': 'v0.9',
      'createSurface': <String, Object?>{
        'surfaceId': id,
        'catalogId': catalogId,
        'sendDataModel': false,
      },
    };

Map<String, Object?> _components(
  String id, {
  String component = 'KeyIndicator',
}) => <String, Object?>{
  'version': 'v0.9',
  'updateComponents': <String, Object?>{
    'surfaceId': id,
    'components': <Object?>[
      <String, Object?>{
        'id': 'root',
        'component': component,
        'data': <String, Object?>{'path': '/kpi'},
      },
    ],
  },
};

Map<String, Object?> _delete(String id) => <String, Object?>{
  'version': 'v0.9',
  'deleteSurface': <String, Object?>{'surfaceId': id},
};

A2uiEnvelopeReceived _event(Map<String, Object?> raw, {String? agent}) =>
    A2uiEnvelopeReceived(
      message: a2ui.A2uiMessage.fromJson(raw),
      raw: raw,
      agent: agent,
      task: agent == null ? null : 'task_1',
    );

String _kind(a2ui.A2uiMessage m) =>
    m.toJson().keys.firstWhere((k) => k != 'version');

void main() {
  late StreamController<SessionEvent> input;
  late List<String> rejected;
  late A2uiGate gate;
  late List<ValidatedEnvelope> validated;
  late List<a2ui.A2uiMessage> accepted;

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() {
    input = StreamController<SessionEvent>.broadcast();
    rejected = <String>[];
    gate = A2uiGate(catalogId: _catalog, onRejected: rejected.add);
    validated = <ValidatedEnvelope>[];
    accepted = <a2ui.A2uiMessage>[];
    gate.validated.listen(validated.add);
    gate.accepted.listen(accepted.add);
    gate.attach(input.stream);
  });
  tearDown(() async {
    await gate.dispose();
    await input.close();
  });

  test('les messages conformes passent aux deux flux, dans l\'ordre', () async {
    input
      ..add(_event(_create('kpi'), agent: 'Qualité'))
      ..add(_event(_components('kpi'), agent: 'Qualité'));
    await settle();

    expect(accepted.map(_kind), <String>['createSurface', 'updateComponents']);
    expect(
      validated.map((e) => e.verdict),
      everyElement(isA<ValidationAccepted>()),
    );
    expect(validated.first.agent, 'Qualité');
    expect(validated.first.task, 'task_1');
    expect(rejected, isEmpty);
  });

  test(
    'les événements qui ne sont pas des messages A2UI sont ignorés',
    () async {
      input.add(const OrbLevelChanged(0.5));
      await settle();

      expect(validated, isEmpty);
      expect(accepted, isEmpty);
    },
  );

  test(
    'un message refusé va au flux validé seul et consigne le code',
    () async {
      input.add(_event(_create('kpi', catalogId: 'https://autre.test/c')));
      await settle();

      expect(accepted, isEmpty);
      expect(validated.single.verdict, const ValidationRejected('bad_catalog'));
      expect(rejected, <String>['bad_catalog']);
    },
  );

  test('un refus n\'interrompt pas le flux', () async {
    input
      ..add(_event(_components('absente')))
      ..add(_event(_create('kpi')))
      ..add(_event(_components('kpi')));
    await settle();

    expect(validated.map((e) => e.verdict), <ValidationVerdict>[
      const ValidationRejected('unknown_surface'),
      const ValidationAccepted(),
      const ValidationAccepted(),
    ]);
    expect(accepted.map(_kind), <String>['createSurface', 'updateComponents']);
  });

  test(
    'un refus sur une surface existante envoie un deleteSurface local',
    () async {
      input
        ..add(_event(_create('kpi')))
        ..add(_event(_components('kpi', component: 'Inconnu')))
        ..add(_event(_components('kpi')));
      await settle();

      expect(accepted.map(_kind), <String>['createSurface', 'deleteSurface']);
      expect((accepted.last as a2ui.DeleteSurfaceMessage).surfaceId, 'kpi');
      expect(
        validated[1].verdict,
        const ValidationRejected('component_not_allowed'),
      );
      // Surface bloquée jusqu'à un nouveau createSurface.
      expect(validated[2].verdict, const ValidationRejected('unknown_surface'));
      expect(rejected, <String>['component_not_allowed', 'unknown_surface']);
    },
  );

  test(
    'un deleteSurface d\'une surface absente est ignoré : flux validé seul',
    () async {
      input.add(_event(_delete('fantome')));
      await settle();

      expect(validated.single.verdict, const ValidationIgnored());
      expect(accepted, isEmpty);
      expect(rejected, isEmpty);
    },
  );

  test('reset remet le validateur à zéro', () async {
    input
      ..add(_event(_create('kpi')))
      ..add(_event(_create('kpi')));
    await settle();
    expect(validated.last.verdict, const ValidationRejected('surface_exists'));

    gate.reset();
    input.add(_event(_create('kpi')));
    await settle();

    expect(validated.last.verdict, const ValidationAccepted());
  });

  test('le rejeu passe par le même gate (raw = JSON du message)', () async {
    final replay = StreamController<a2ui.A2uiMessage>();
    final second = A2uiGate(catalogId: _catalog, onRejected: rejected.add);
    addTearDown(second.dispose);
    final out = <a2ui.A2uiMessage>[];
    final seen = <ValidatedEnvelope>[];
    second.validated.listen(seen.add);
    second.accepted.listen(out.add);
    second.attach(A2uiGate.replayEvents(replay.stream));

    replay
      ..add(a2ui.A2uiMessage.fromJson(_create('kpi')))
      ..add(
        a2ui.A2uiMessage.fromJson(_components('kpi', component: 'Inconnu')),
      );
    await settle();

    expect(seen.map((e) => e.verdict), <ValidationVerdict>[
      const ValidationAccepted(),
      const ValidationRejected('component_not_allowed'),
    ]);
    expect(seen.first.raw['createSurface'], isA<Map<String, Object?>>());
    expect(out.map(_kind), <String>['createSurface', 'deleteSurface']);
  });

  test(
    'la fin et l\'erreur de la source sont relayées au flux accepté',
    () async {
      final source = StreamController<SessionEvent>();
      final other = A2uiGate(catalogId: _catalog);
      final events = <String>[];
      other.accepted.listen(
        (_) {},
        onError: (Object e) => events.add('erreur $e'),
        onDone: () => events.add('fin'),
      );
      other.attach(source.stream);

      source.addError('boom');
      await source.close();
      await settle();

      expect(events, <String>['erreur boom', 'fin']);
      await other.dispose();
    },
  );

  test('dispose ferme les flux et se désabonne de la source', () async {
    final done = <String>[];
    final other = A2uiGate(catalogId: _catalog);
    other.validated.listen(null, onDone: () => done.add('validated'));
    other.accepted.listen(null, onDone: () => done.add('accepted'));
    other.attach(input.stream);

    await other.dispose();
    await other.dispose();

    expect(done, unorderedEquals(<String>['validated', 'accepted']));
    expect(input.hasListener, isTrue); // celui du gate de `setUp`.
    other.reset(); // sans effet ni exception après fermeture.
  });
}
