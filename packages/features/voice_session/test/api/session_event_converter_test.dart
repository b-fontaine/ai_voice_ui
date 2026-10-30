import 'package:a2ui_core/a2ui_core.dart' show CreateSurfaceMessage;
import 'package:entity_session/entity_session.dart';
import 'package:feature_voice_session/src/api/session_event_converter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_backend_channel/shared_backend_channel.dart';

AppChannelEnvelope _env(
  String type,
  Map<String, Object?> data, {
  String? agent,
  String? task,
}) => AppChannelEnvelope(
  version: 1,
  type: type,
  session: 's1',
  tMs: 5,
  data: data,
  agent: agent,
  task: task,
);

const Map<String, Object?> _createSurface = <String, Object?>{
  'version': 'v0.9',
  'createSurface': <String, Object?>{
    'surfaceId': 'quality',
    'catalogId':
        'https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json',
    'sendDataModel': true,
  },
};

void main() {
  late List<String> ignored;
  late SessionEventConverter converter;

  setUp(() {
    ignored = <String>[];
    converter = SessionEventConverter(onIgnored: ignored.add);
  });

  group('SessionEventConverter conversions', () {
    final Map<String, (AppChannelEnvelope, SessionEvent)>
    table = <String, (AppChannelEnvelope, SessionEvent)>{
      'orb.level': (
        _env('orb.level', <String, Object?>{'level': 0.4}),
        const OrbLevelChanged(0.4),
      ),
      'orb.level entier': (
        _env('orb.level', <String, Object?>{'level': 1}),
        const OrbLevelChanged(1),
      ),
      'transcript': (
        _env('transcript', <String, Object?>{
          'role': 'ai',
          'text': 'Bonjour',
          'start_ms': 10,
          'end_ms': 20,
        }),
        const TranscriptDelta(
          role: TranscriptRole.ai,
          text: 'Bonjour',
          startMs: 10,
          endMs: 20,
        ),
      ),
      'session.state avec raison': (
        _env('session.state', <String, Object?>{
          'state': 'closed',
          'reason': 'expired',
        }),
        const SessionStateChanged(
          state: SessionState.closed,
          reason: 'expired',
        ),
      ),
      'session.state sans raison': (
        _env('session.state', <String, Object?>{'state': 'active'}),
        const SessionStateChanged(state: SessionState.active),
      ),
      'usage': (
        _env('usage', <String, Object?>{'seconds': 4, 'context_ratio': 0.02}),
        const UsageUpdated(seconds: 4, contextRatio: 0.02),
      ),
      'usage ratio entier': (
        _env('usage', <String, Object?>{'seconds': 4, 'context_ratio': 1}),
        const UsageUpdated(seconds: 4, contextRatio: 1),
      ),
      'delegation': (
        _env('delegation', <String, Object?>{
          'id': 'deleg_1',
          'offset_ms': 2100,
        }),
        const DelegationStarted(id: 'deleg_1', offsetMs: 2100),
      ),
      'agent.activity complet': (
        _env('agent.activity', <String, Object?>{
          'agent': 'Qualité',
          'task': 't1',
          'state': 'failed',
          'label': 'Qualité',
          'detail': 'délai dépassé',
        }),
        const AgentActivityReceived(
          agent: 'Qualité',
          task: 't1',
          state: AgentTaskState.failed,
          label: 'Qualité',
          detail: 'délai dépassé',
        ),
      ),
      'agent.activity rejected': (
        _env('agent.activity', <String, Object?>{
          'agent': 'Qualité',
          'task': 't',
          'state': 'rejected',
          'detail': 'hors périmètre',
        }),
        const AgentActivityReceived(
          agent: 'Qualité',
          task: 't',
          state: AgentTaskState.rejected,
          detail: 'hors périmètre',
        ),
      ),
      'plan': (
        _env('plan', <String, Object?>{
          'delegation': 'd1',
          'selected': <Object?>['Voix du client'],
          'idle': <Object?>['Qualité', 'Livraison'],
        }),
        PlanReceived(
          delegation: 'd1',
          selected: const <String>['Voix du client'],
          idle: const <String>['Qualité', 'Livraison'],
        ),
      ),
      'plan vide': (
        _env('plan', <String, Object?>{
          'delegation': 'd2',
          'selected': <Object?>[],
          'idle': <Object?>['Qualité'],
        }),
        PlanReceived(
          delegation: 'd2',
          selected: const <String>[],
          idle: const <String>['Qualité'],
        ),
      ),
      'agent.activity repli sur l\'enveloppe': (
        _env(
          'agent.activity',
          <String, Object?>{'state': 'working'},
          agent: 'Env',
          task: 'tEnv',
        ),
        const AgentActivityReceived(
          agent: 'Env',
          task: 'tEnv',
          state: AgentTaskState.working,
        ),
      ),
      'agent.activity : data prime sur l\'enveloppe': (
        _env(
          'agent.activity',
          <String, Object?>{'agent': 'D', 'task': 'tD', 'state': 'completed'},
          agent: 'Env',
          task: 'tEnv',
        ),
        const AgentActivityReceived(
          agent: 'D',
          task: 'tD',
          state: AgentTaskState.completed,
        ),
      ),
    };

    for (final MapEntry<String, (AppChannelEnvelope, SessionEvent)> e
        in table.entries) {
      test(e.key, () {
        expect(converter.convert(e.value.$1), e.value.$2);
        expect(ignored, isEmpty);
      });
    }

    test('orb.level est borné à 0..1', () {
      expect(
        converter.convert(_env('orb.level', <String, Object?>{'level': 1.7})),
        const OrbLevelChanged(1),
      );
      expect(
        converter.convert(_env('orb.level', <String, Object?>{'level': -0.3})),
        const OrbLevelChanged(0),
      );
    });

    test('a2ui valide : message décodé, corps brut, agent et tâche', () {
      final SessionEvent? event = converter.convert(
        _env('a2ui', _createSurface, agent: 'Qualité', task: 't1'),
      );

      expect(event, isA<A2uiEnvelopeReceived>());
      final received = event! as A2uiEnvelopeReceived;
      expect(received.message, isA<CreateSurfaceMessage>());
      expect(received.raw, _createSurface);
      expect(received.agent, 'Qualité');
      expect(received.task, 't1');
      expect(ignored, isEmpty);
    });
  });

  group('SessionEventConverter ignorés', () {
    final Map<String, (AppChannelEnvelope, String)> table =
        <String, (AppChannelEnvelope, String)>{
          'type inconnu': (
            _env('inconnu', <String, Object?>{}),
            'type de message inconnu',
          ),
          'orb.level sans level': (
            _env('orb.level', <String, Object?>{}),
            'champ manquant ou mal typé',
          ),
          'orb.level texte': (
            _env('orb.level', <String, Object?>{'level': 'fort'}),
            'champ manquant ou mal typé',
          ),
          'orb.level NaN': (
            _env('orb.level', <String, Object?>{'level': double.nan}),
            'champ manquant ou mal typé',
          ),
          'transcript sans texte': (
            _env('transcript', <String, Object?>{
              'role': 'ai',
              'start_ms': 1,
              'end_ms': 2,
            }),
            'champ manquant ou mal typé',
          ),
          'transcript rôle inconnu': (
            _env('transcript', <String, Object?>{
              'role': 'system',
              'text': 'x',
              'start_ms': 1,
              'end_ms': 2,
            }),
            'valeur d\'énumération inconnue',
          ),
          'session.state inconnu': (
            _env('session.state', <String, Object?>{'state': 'paused'}),
            'valeur d\'énumération inconnue',
          ),
          'session.state raison mal typée': (
            _env('session.state', <String, Object?>{
              'state': 'closed',
              'reason': 3,
            }),
            'champ manquant ou mal typé',
          ),
          'usage sans ratio': (
            _env('usage', <String, Object?>{'seconds': 3}),
            'champ manquant ou mal typé',
          ),
          'delegation sans id': (
            _env('delegation', <String, Object?>{'offset_ms': 3}),
            'champ manquant ou mal typé',
          ),
          'agent.activity état inconnu': (
            _env('agent.activity', <String, Object?>{
              'agent': 'a',
              'task': 't',
              'state': 'canceled',
            }),
            'valeur d\'énumération inconnue',
          ),
          'agent.activity sans agent ni repli': (
            _env('agent.activity', <String, Object?>{
              'task': 't',
              'state': 'working',
            }),
            'champ manquant ou mal typé',
          ),
          'agent.activity label mal typé': (
            _env('agent.activity', <String, Object?>{
              'agent': 'a',
              'task': 't',
              'state': 'working',
              'label': 1,
            }),
            'champ manquant ou mal typé',
          ),
          'plan sans selected': (
            _env('plan', <String, Object?>{
              'delegation': 'd',
              'idle': <Object?>[],
            }),
            'champ manquant ou mal typé',
          ),
          'plan selected null': (
            _env('plan', <String, Object?>{
              'delegation': 'd',
              'selected': null,
              'idle': <Object?>[],
            }),
            'champ manquant ou mal typé',
          ),
          'plan idle mal typé': (
            _env('plan', <String, Object?>{
              'delegation': 'd',
              'selected': <Object?>[],
              'idle': 'Qualité',
            }),
            'champ manquant ou mal typé',
          ),
          'plan élément non chaîne': (
            _env('plan', <String, Object?>{
              'delegation': 'd',
              'selected': <Object?>[1],
              'idle': <Object?>[],
            }),
            'champ manquant ou mal typé',
          ),
          'plan sans delegation': (
            _env('plan', <String, Object?>{
              'selected': <Object?>[],
              'idle': <Object?>[],
            }),
            'champ manquant ou mal typé',
          ),
          'a2ui refusé par le décodeur': (
            _env('a2ui', <String, Object?>{'version': 'v0.8'}),
            'message A2UI refusé',
          ),
        };

    for (final MapEntry<String, (AppChannelEnvelope, String)> e
        in table.entries) {
      test(e.key, () {
        expect(converter.convert(e.value.$1), isNull);
        expect(ignored, <String>[e.value.$2]);
      });
    }

    test('sans callback : null sans exception', () {
      expect(
        const SessionEventConverter().convert(_env('inconnu', const {})),
        isNull,
      );
    });

    test('la raison ne reprend jamais le contenu reçu', () {
      converter.convert(
        _env('transcript', <String, Object?>{
          'role': 'secret-role',
          'text': 'secret-text',
          'start_ms': 1,
          'end_ms': 2,
        }),
      );
      converter.convert(_env('secret-type', <String, Object?>{}));
      expect(ignored.join(), isNot(contains('secret')));
    });
  });
}
