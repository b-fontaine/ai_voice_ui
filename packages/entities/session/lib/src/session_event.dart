import 'package:a2ui_core/a2ui_core.dart' show A2uiMessage;

/// Rôle d'un fragment de transcription.
enum TranscriptRole { user, ai }

/// État de la session vocale vu par l'application.
enum SessionState { connecting, active, closed }

/// État d'une activité d'agent.
enum AgentActivityState { working, completed, failed }

/// Événement de session, produit par le canal applicatif et consommé par les
/// Blocs. Hiérarchie fermée : un `switch` sans `default` doit être exhaustif.
sealed class SessionEvent {
  const SessionEvent();
}

/// Fragment de transcription (parole de l'utilisateur ou de l'IA).
final class TranscriptDelta extends SessionEvent {
  const TranscriptDelta({
    required this.role,
    required this.text,
    required this.startMs,
    required this.endMs,
  });

  final TranscriptRole role;
  final String text;
  final int startMs;
  final int endMs;

  @override
  bool operator ==(Object other) =>
      other is TranscriptDelta &&
      other.role == role &&
      other.text == text &&
      other.startMs == startMs &&
      other.endMs == endMs;

  @override
  int get hashCode => Object.hash(role, text, startMs, endMs);
}

/// Nouveau niveau sonore brut pour l'orbe.
final class OrbLevelChanged extends SessionEvent {
  const OrbLevelChanged(this.level);

  final double level;

  @override
  bool operator ==(Object other) =>
      other is OrbLevelChanged && other.level == level;

  @override
  int get hashCode => level.hashCode;
}

/// Changement d'état de la session, avec une raison éventuelle.
final class SessionStateChanged extends SessionEvent {
  const SessionStateChanged({required this.state, this.reason});

  final SessionState state;
  final String? reason;

  @override
  bool operator ==(Object other) =>
      other is SessionStateChanged &&
      other.state == state &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(state, reason);
}

/// Début d'une délégation à un agent.
final class DelegationStarted extends SessionEvent {
  const DelegationStarted({required this.id, required this.offsetMs});

  final String id;
  final int offsetMs;

  @override
  bool operator ==(Object other) =>
      other is DelegationStarted &&
      other.id == id &&
      other.offsetMs == offsetMs;

  @override
  int get hashCode => Object.hash(id, offsetMs);
}

/// Activité d'un agent (en cours, terminée ou en échec).
final class AgentActivityReceived extends SessionEvent {
  const AgentActivityReceived({
    required this.agent,
    required this.task,
    required this.state,
    this.label,
    this.detail,
  });

  final String agent;
  final String task;
  final AgentActivityState state;
  final String? label;
  final String? detail;

  @override
  bool operator ==(Object other) =>
      other is AgentActivityReceived &&
      other.agent == agent &&
      other.task == task &&
      other.state == state &&
      other.label == label &&
      other.detail == detail;

  @override
  int get hashCode => Object.hash(agent, task, state, label, detail);
}

/// Enveloppe A2UI reçue : le message décodé et le corps brut d'origine.
///
/// L'égalité porte sur le corps brut (comparé en profondeur), dont [message]
/// est dérivé, car [A2uiMessage] n'a pas d'égalité par valeur.
final class A2uiEnvelopeReceived extends SessionEvent {
  const A2uiEnvelopeReceived({
    required this.message,
    required this.raw,
    this.agent,
    this.task,
  });

  final A2uiMessage message;
  final Map<String, Object?> raw;
  final String? agent;
  final String? task;

  @override
  bool operator ==(Object other) =>
      other is A2uiEnvelopeReceived &&
      other.agent == agent &&
      other.task == task &&
      _deepEquals(other.raw, raw);

  @override
  int get hashCode => Object.hash(agent, task, _deepHash(raw));
}

/// Consommation de la session : durée écoulée et taux de remplissage du contexte.
final class UsageUpdated extends SessionEvent {
  const UsageUpdated({required this.seconds, required this.contextRatio});

  final int seconds;
  final double contextRatio;

  @override
  bool operator ==(Object other) =>
      other is UsageUpdated &&
      other.seconds == seconds &&
      other.contextRatio == contextRatio;

  @override
  int get hashCode => Object.hash(seconds, contextRatio);
}

/// Perte du canal applicatif.
final class ChannelLost extends SessionEvent {
  const ChannelLost(this.reason);

  final String reason;

  @override
  bool operator ==(Object other) =>
      other is ChannelLost && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;
}

bool _deepEquals(Object? a, Object? b) {
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final Object? key in a.keys) {
      if (!b.containsKey(key) || !_deepEquals(a[key], b[key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

int _deepHash(Object? value) {
  if (value is Map) {
    // Indépendant de l'ordre des clés, comme l'égalité.
    int hash = value.length;
    for (final MapEntry<Object?, Object?> e in value.entries) {
      hash ^= Object.hash(e.key, _deepHash(e.value));
    }
    return hash;
  }
  if (value is List) return Object.hashAll(value.map(_deepHash));
  return value.hashCode;
}
