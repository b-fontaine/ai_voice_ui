import 'package:a2ui_core/a2ui_core.dart' show A2uiMessage;
import 'package:entity_session/entity_session.dart';
import 'package:test/test.dart';

A2uiMessage _message() => A2uiMessage.fromJson(<String, Object?>{
  'version': 'v0.9',
  'deleteSurface': <String, Object?>{'surfaceId': 's1'},
});

void main() {
  final Map<String, Object?> raw = <String, Object?>{
    'version': 'v0.9',
    'deleteSurface': <String, Object?>{'surfaceId': 's1'},
  };

  // Chaque entrée : deux instances égales, une instance différente.
  final Map<String, (SessionEvent, SessionEvent, SessionEvent)> cases =
      <String, (SessionEvent, SessionEvent, SessionEvent)>{
        'TranscriptDelta': (
          const TranscriptDelta(
            role: TranscriptRole.user,
            text: 'a',
            startMs: 0,
            endMs: 10,
          ),
          const TranscriptDelta(
            role: TranscriptRole.user,
            text: 'a',
            startMs: 0,
            endMs: 10,
          ),
          const TranscriptDelta(
            role: TranscriptRole.ai,
            text: 'a',
            startMs: 0,
            endMs: 10,
          ),
        ),
        'OrbLevelChanged': (
          const OrbLevelChanged(0.5),
          const OrbLevelChanged(0.5),
          const OrbLevelChanged(0.6),
        ),
        'SessionStateChanged': (
          const SessionStateChanged(state: SessionState.closed, reason: 'x'),
          const SessionStateChanged(state: SessionState.closed, reason: 'x'),
          const SessionStateChanged(state: SessionState.closed),
        ),
        'DelegationStarted': (
          const DelegationStarted(id: 'd', offsetMs: 1),
          const DelegationStarted(id: 'd', offsetMs: 1),
          const DelegationStarted(id: 'd', offsetMs: 2),
        ),
        'AgentActivityReceived': (
          const AgentActivityReceived(
            agent: 'a',
            task: 't',
            state: AgentActivityState.failed,
            label: 'l',
            detail: 'd',
          ),
          const AgentActivityReceived(
            agent: 'a',
            task: 't',
            state: AgentActivityState.failed,
            label: 'l',
            detail: 'd',
          ),
          const AgentActivityReceived(
            agent: 'a',
            task: 't',
            state: AgentActivityState.working,
          ),
        ),
        'A2uiEnvelopeReceived': (
          A2uiEnvelopeReceived(
            message: _message(),
            raw: raw,
            agent: 'a',
            task: 't',
          ),
          A2uiEnvelopeReceived(
            message: _message(),
            raw: Map<String, Object?>.of(raw),
            agent: 'a',
            task: 't',
          ),
          A2uiEnvelopeReceived(message: _message(), raw: raw, agent: 'b'),
        ),
        'UsageUpdated': (
          const UsageUpdated(seconds: 3, contextRatio: 0.2),
          const UsageUpdated(seconds: 3, contextRatio: 0.2),
          const UsageUpdated(seconds: 4, contextRatio: 0.2),
        ),
        'ChannelLost': (
          const ChannelLost('r'),
          const ChannelLost('r'),
          const ChannelLost('s'),
        ),
      };

  for (final MapEntry<String, (SessionEvent, SessionEvent, SessionEvent)> c
      in cases.entries) {
    test('${c.key} : égalité et hashCode par valeur', () {
      final (SessionEvent a, SessionEvent b, SessionEvent other) = c.value;
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(other)));
    });
  }

  test('le switch sur SessionEvent est exhaustif (sans default)', () {
    // Si une variante manque, ce test ne compile plus.
    String name(SessionEvent e) => switch (e) {
      TranscriptDelta() => 'TranscriptDelta',
      OrbLevelChanged() => 'OrbLevelChanged',
      SessionStateChanged() => 'SessionStateChanged',
      DelegationStarted() => 'DelegationStarted',
      AgentActivityReceived() => 'AgentActivityReceived',
      A2uiEnvelopeReceived() => 'A2uiEnvelopeReceived',
      UsageUpdated() => 'UsageUpdated',
      ChannelLost() => 'ChannelLost',
    };
    final Set<String> names = cases.values
        .map(((SessionEvent, SessionEvent, SessionEvent) t) => name(t.$1))
        .toSet();
    expect(names, cases.keys.toSet());
  });

  test('SessionEventSource expose un flux d\'événements', () {
    final SessionEventSource source = _Source();
    expect(source.events, emits(const OrbLevelChanged(0.1)));
  });
}

final class _Source implements SessionEventSource {
  @override
  Stream<SessionEvent> get events =>
      Stream<SessionEvent>.value(const OrbLevelChanged(0.1));
}
