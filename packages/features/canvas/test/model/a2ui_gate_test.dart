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

typedef Replayed = ({Map<String, Object?> raw, a2ui.A2uiMessage message});

Replayed _replayed(Map<String, Object?> raw) =>
    (raw: raw, message: a2ui.A2uiMessage.fromJson(raw));

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
    gate.validatedBranch().listen(validated.add);
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
    'un createSurface en double est refusé sans deleteSurface local',
    () async {
      input
        ..add(_event(_create('kpi')))
        ..add(_event(_create('kpi')))
        ..add(_event(_components('kpi')));
      await settle();

      expect(validated.map((e) => e.verdict), <ValidationVerdict>[
        const ValidationAccepted(),
        const ValidationRejected('surface_exists'),
        const ValidationAccepted(),
      ]);
      expect(validated[1].compensations, isEmpty);
      expect(accepted.map(_kind), <String>[
        'createSurface',
        'updateComponents',
      ]);
      expect(rejected, <String>['surface_exists']);
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

  test('le rejeu passe par le même gate (raw = ligne brute)', () async {
    final replay = StreamController<Replayed>();
    final second = A2uiGate(catalogId: _catalog, onRejected: rejected.add);
    addTearDown(second.dispose);
    final out = <a2ui.A2uiMessage>[];
    final seen = <ValidatedEnvelope>[];
    second.validatedBranch().listen(seen.add);
    second.accepted.listen(out.add);
    second.attach(A2uiGate.replayEvents(replay.stream));

    replay
      ..add(_replayed(_create('kpi')))
      ..add(_replayed(_components('kpi', component: 'Inconnu')));
    await settle();

    expect(seen.map((e) => e.verdict), <ValidationVerdict>[
      const ValidationAccepted(),
      const ValidationRejected('component_not_allowed'),
    ]);
    expect(seen.first.raw['createSurface'], isA<Map<String, Object?>>());
    expect(out.map(_kind), <String>['createSurface', 'deleteSurface']);
  });

  test('le rejeu valide la ligne BRUTE, pas le JSON reconstruit : une '
      'propriété que le décodeur écarte est refusée', () async {
    final replay = StreamController<Replayed>();
    final second = A2uiGate(catalogId: _catalog, onRejected: rejected.add);
    addTearDown(second.dispose);
    final seen = <ValidatedEnvelope>[];
    second.validatedBranch().listen(seen.add);
    second.attach(A2uiGate.replayEvents(replay.stream));
    // Le message décodé ne porte pas `color` ; la ligne brute, si.
    final Map<String, Object?> decodedSide = _components('kpi');
    final Map<String, Object?> raw = _components('kpi');
    final List<Object?> components =
        (raw['updateComponents']! as Map<String, Object?>)['components']!
            as List<Object?>;
    (components.single! as Map<String, Object?>)['color'] = '#ff0000';

    replay
      ..add(_replayed(_create('kpi')))
      ..add((raw: raw, message: a2ui.A2uiMessage.fromJson(decodedSide)));
    await settle();

    expect(seen.last.verdict, const ValidationRejected('bad_property'));
    expect(rejected, contains('bad_property'));
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
    other.validatedBranch().listen(null, onDone: () => done.add('validated'));
    other.accepted.listen(null, onDone: () => done.add('accepted'));
    other.attach(input.stream);

    await other.dispose();
    await other.dispose();

    expect(done, unorderedEquals(<String>['validated', 'accepted']));
    expect(input.hasListener, isTrue); // celui du gate de `setUp`.
    other.reset(); // sans effet ni exception après fermeture.
  });

  group('validatedBranch : branche à abonné unique, mise en mémoire', () {
    test(
      'reçoit les messages émis AVANT son écoute, avec leur verdict',
      () async {
        final other = A2uiGate(catalogId: _catalog);
        final branch = other.validatedBranch();
        final source = StreamController<SessionEvent>();
        other.attach(source.stream);
        source
          ..add(_event(_create('kpi')))
          ..add(_event(_components('kpi', component: 'Column')));
        await settle();

        // Le consommateur (un Bloc) ne s'abonne qu'après quelques tours.
        final seen = <ValidatedEnvelope>[];
        branch.listen(seen.add);
        await settle();

        expect(seen, hasLength(2));
        expect(seen.first.verdict, isA<ValidationAccepted>());
        expect(seen.last.verdict, isA<ValidationRejected>());
        await other.dispose();
        await source.close();
      },
    );

    test('deux branches reçoivent chacune tous les messages', () async {
      final a = <ValidatedEnvelope>[];
      final b = <ValidatedEnvelope>[];
      gate.validatedBranch().listen(a.add);
      gate.validatedBranch().listen(b.add);

      input.add(_event(_create('kpi')));
      await settle();

      expect(a, hasLength(1));
      expect(b, hasLength(1));
    });

    test('la fin du gate ferme la branche écoutée', () async {
      final other = A2uiGate(catalogId: _catalog);
      final done = <String>[];
      other.validatedBranch().listen(null, onDone: () => done.add('fin'));
      other.attach(input.stream);

      await other.dispose();
      await settle();

      expect(done, <String>['fin']);
    });

    test('une branche demandée après la fermeture est déjà terminée', () async {
      final other = A2uiGate(catalogId: _catalog);
      await other.dispose();
      final done = <String>[];

      other.validatedBranch().listen(null, onDone: () => done.add('fin'));
      await settle();

      expect(done, <String>['fin']);
    });

    test(
      'une branche annulée ne retient rien et n\'empêche pas la suite',
      () async {
        final branch = gate.validatedBranch().listen((_) {});
        await branch.cancel();

        input.add(_event(_create('kpi')));
        await settle();

        expect(validated, hasLength(1));
      },
    );
  });
}
