import 'package:a2ui_core/a2ui_core.dart' show A2uiMessage;
import 'package:collection/collection.dart' show DeepCollectionEquality;

const DeepCollectionEquality _deepEq = DeepCollectionEquality();

/// Rôle d'un fragment de transcription.
enum TranscriptRole { user, ai }

/// État de la session vocale vu par l'application.
enum SessionState { connecting, active, closed }

/// État d'une tâche A2A d'agent. `rejected` : l'agent retenu refuse la
/// demande (hors périmètre), ce qui n'est pas un échec. `canceled` : la
/// tâche a été annulée (interruption vocale), ce qui n'est pas un échec non plus.
enum AgentTaskState { working, completed, failed, rejected, canceled }

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
  final AgentTaskState state;
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
      _deepEq.equals(other.raw, raw);

  @override
  int get hashCode => Object.hash(agent, task, _deepEq.hash(raw));
}

/// Plan de l'orchestrateur pour une délégation (pdr-0013) : agents retenus
/// ([selected], dans l'ordre reçu) et agents laissés en veille ([idle]).
/// Un [selected] vide signifie une demande hors catalogue (RG-08).
final class PlanReceived extends SessionEvent {
  PlanReceived({
    required this.delegation,
    required List<String> selected,
    required List<String> idle,
  }) : selected = List<String>.unmodifiable(selected),
       idle = List<String>.unmodifiable(idle);

  final String delegation;
  final List<String> selected;
  final List<String> idle;

  @override
  bool operator ==(Object other) =>
      other is PlanReceived &&
      other.delegation == delegation &&
      _deepEq.equals(other.selected, selected) &&
      _deepEq.equals(other.idle, idle);

  @override
  int get hashCode =>
      Object.hash(delegation, _deepEq.hash(selected), _deepEq.hash(idle));
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

/// Cause d'une interruption de l'IA (`voice.interrupted`) : un mot d'arrêt
/// (`stop`), une correction de la demande (`correction`, pdr-0076) ou une prise
/// de parole sur la voix de l'IA sans mot d'arrêt (`overlap`, pdr-0077).
enum InterruptionCause { stop, correction, overlap }

/// L'utilisateur a interrompu l'IA (`voice.interrupted`). [atMs] est l'horloge
/// média des transcripts (`start_ms` du delta déclencheur). [cause] vaut
/// `stop` quand le message ne la précise pas.
final class VoiceInterrupted extends SessionEvent {
  const VoiceInterrupted({
    required this.atMs,
    this.cause = InterruptionCause.stop,
  });

  final int atMs;
  final InterruptionCause cause;

  @override
  bool operator ==(Object other) =>
      other is VoiceInterrupted && other.atMs == atMs && other.cause == cause;

  @override
  int get hashCode => Object.hash(atMs, cause);
}

/// L'utilisateur a fait taire l'IA localement (bouton ou `Échap`). Événement
/// purement local : il n'a pas d'horloge média, n'est jamais écrit dans le
/// journal des enveloppes ni dans celui d'A2UI, et n'est jamais envoyé au
/// backend.
final class VoiceSilenced extends SessionEvent {
  const VoiceSilenced();

  @override
  bool operator ==(Object other) => other is VoiceSilenced;

  @override
  int get hashCode => (VoiceSilenced).hashCode;
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
