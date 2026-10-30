import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_backend_channel/shared_backend_channel.dart';

String _env({
  Object? v = 1,
  Object? type = 'orb.level',
  Object? session = 's1',
  Object? tMs = 10,
  Object? data = const <String, Object?>{},
  Object? agent,
  Object? task,
  Set<String> omit = const {},
}) {
  final map = <String, Object?>{
    'v': v,
    'type': type,
    'session': session,
    't_ms': tMs,
    'data': data,
    'agent': ?agent,
    'task': ?task,
  };
  omit.forEach(map.remove);
  return jsonEncode(map);
}

void main() {
  group('AppChannelEnvelopeTest valides', () {
    final valid = <String, String>{
      AppChannelTypes.orbLevel: _env(data: {'level': 0.42}),
      AppChannelTypes.transcript: _env(
        type: 'transcript',
        data: {'role': 'user', 'text': 'Salut', 'start_ms': 1, 'end_ms': 2},
      ),
      '${AppChannelTypes.sessionState} sans reason': _env(
        type: 'session.state',
        data: {'state': 'active'},
      ),
      '${AppChannelTypes.sessionState} avec reason': _env(
        type: 'session.state',
        data: {'state': 'closed', 'reason': 'user'},
      ),
      AppChannelTypes.usage: _env(
        type: 'usage',
        data: {'seconds': 4, 'context_ratio': 0.02},
      ),
      AppChannelTypes.delegation: _env(
        type: 'delegation',
        data: {'id': 'deleg_1', 'offset_ms': 2100},
      ),
      AppChannelTypes.agentActivity: _env(
        type: 'agent.activity',
        data: {'agent': 'Qualité', 'task': 't1', 'state': 'working'},
        agent: 'Qualité',
        task: 't1',
      ),
      AppChannelTypes.a2ui: _env(
        type: 'a2ui',
        data: {
          'version': 'v0.9',
          'createSurface': {'surfaceId': 'quality'},
        },
        agent: 'Qualité',
        task: 't1',
      ),
    };
    for (final entry in valid.entries) {
      test('accepte ${entry.key}', () {
        final env = AppChannelEnvelope.parse(entry.value);
        expect(env.version, 1);
        expect(env.session, 's1');
        expect(env.tMs, 10);
        expect(entry.key, startsWith(env.type));
      });
    }

    test('agent et task de premier niveau sont lus', () {
      final env = AppChannelEnvelope.parse(
        _env(type: 'agent.activity', agent: 'Qualité', task: 't1'),
      );
      expect(env.agent, 'Qualité');
      expect(env.task, 't1');
    });

    test('a2ui garde data comme Map brute', () {
      final env = AppChannelEnvelope.parse(
        _env(type: 'a2ui', data: {'version': 'v0.9', 'x': 1}),
      );
      expect(env.data, {'version': 'v0.9', 'x': 1});
    });

    test('type inconnu accepté', () {
      expect(
        AppChannelEnvelope.parse(_env(type: 'futur.type')).type,
        'futur.type',
      );
    });

    test('égalité par valeur', () {
      final a = AppChannelEnvelope.parse(_env(data: {'level': 1}));
      final b = AppChannelEnvelope.parse(_env(data: {'level': 1}));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(AppChannelEnvelope.parse(_env(data: {'level': 2}))));
    });
  });

  group('AppChannelEnvelopeTest refus', () {
    void refuse(String name, String json, String message) {
      test(name, () {
        expect(
          () => AppChannelEnvelope.parse(json),
          throwsA(
            isA<AppChannelFormatException>().having(
              (e) => e.reason,
              'reason',
              message,
            ),
          ),
        );
      });
    }

    refuse('JSON illisible', '{pas du json', 'JSON invalide');
    refuse('tableau JSON', '[1,2]', 'JSON invalide');
    refuse('version 2', _env(v: 2), 'version non prise en charge');
    refuse('type vide', _env(type: ''), 'champ manquant ou invalide : type');
    refuse(
      'type absent',
      _env(omit: {'type'}),
      'champ manquant ou invalide : type',
    );
    refuse(
      'type non chaîne',
      _env(type: 3),
      'champ manquant ou invalide : type',
    );
    refuse(
      'session absente',
      _env(omit: {'session'}),
      'champ manquant ou invalide : session',
    );
    refuse('t_ms négatif', _env(tMs: -1), 'champ manquant ou invalide : t_ms');
    refuse('t_ms décimal', _env(tMs: 1.5), 'champ manquant ou invalide : t_ms');
    refuse(
      't_ms absent',
      _env(omit: {'t_ms'}),
      'champ manquant ou invalide : t_ms',
    );
    refuse(
      'data non objet',
      _env(data: [1]),
      'champ manquant ou invalide : data',
    );
    refuse(
      'agent non chaîne',
      _env(agent: 5),
      'champ manquant ou invalide : agent',
    );
    refuse(
      'task non chaîne',
      _env(task: 5),
      'champ manquant ou invalide : task',
    );
    refuse(
      'trop grand',
      _env(data: {'x': 'a' * maxEnvelopeLength}),
      'enveloppe trop grande',
    );

    test('l\'exception ne contient jamais le texte source', () {
      for (final body in [
        '{SECRET-123 pas du json',
        _env(v: 2, session: 'SECRET-123'),
        _env(type: 'SECRET-123', tMs: -1),
        _env(data: 'SECRET-123'),
        _env(agent: ['SECRET-123']),
        _env(data: {'x': 'SECRET-123${'a' * maxEnvelopeLength}'}),
      ]) {
        try {
          AppChannelEnvelope.parse(body);
          fail('aurait dû échouer');
        } on AppChannelFormatException catch (e) {
          expect(e.toString(), isNot(contains('SECRET')));
          expect(e.reason, isNot(contains('SECRET')));
        }
      }
    });
  });
}
