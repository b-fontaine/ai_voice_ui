import 'package:entity_session/entity_session.dart';
import 'package:shared_backend_channel/shared_backend_channel.dart';
import 'package:shared_core/shared_core.dart';

/// Raisons fermées d'un message ignoré (jamais de contenu brut).
abstract final class _Reasons {
  static const String unknownType = 'type de message inconnu';
  static const String badField = 'champ manquant ou mal typé';
  static const String unknownEnum = 'valeur d\'énumération inconnue';
  static const String a2uiRefused = 'message A2UI refusé';
}

/// Convertit une [AppChannelEnvelope] en [SessionEvent].
///
/// Fonction pure : jamais d'exception. Un message inconnu ou invalide donne
/// `null` et appelle [onIgnored] avec une raison fermée, sans contenu reçu.
class SessionEventConverter {
  const SessionEventConverter({this.onIgnored});

  final void Function(String reason)? onIgnored;

  SessionEvent? convert(AppChannelEnvelope envelope) {
    final SessionEvent? event;
    try {
      event = _convert(envelope);
    } on _Ignored catch (ignored) {
      onIgnored?.call(ignored.reason);
      return null;
    }
    return event;
  }

  SessionEvent _convert(AppChannelEnvelope envelope) {
    final Map<String, Object?> data = envelope.data;
    switch (envelope.type) {
      case AppChannelTypes.orbLevel:
        return OrbLevelChanged(_number(data, 'level').clamp(0.0, 1.0));
      case AppChannelTypes.transcript:
        return TranscriptDelta(
          role: _enumValue(data, 'role', const <String, TranscriptRole>{
            'user': TranscriptRole.user,
            'ai': TranscriptRole.ai,
          }),
          text: _string(data, 'text'),
          startMs: _int(data, 'start_ms'),
          endMs: _int(data, 'end_ms'),
        );
      case AppChannelTypes.sessionState:
        // `connecting` et `active` du backend sont redondants avec l'état
        // local (`VoiceSessionStatus`, source de vérité de `LiveSessionEventSource`) ;
        // ils sont convertis par fidélité au contrat (testé par T17) et seul
        // `closed` est exploité par la source d'événements.
        return SessionStateChanged(
          state: _enumValue(data, 'state', const <String, SessionState>{
            'connecting': SessionState.connecting,
            'active': SessionState.active,
            'closed': SessionState.closed,
          }),
          reason: _optionalString(data, 'reason'),
        );
      case AppChannelTypes.usage:
        return UsageUpdated(
          seconds: _int(data, 'seconds'),
          contextRatio: _number(data, 'context_ratio'),
        );
      case AppChannelTypes.delegation:
        return DelegationStarted(
          id: _string(data, 'id'),
          offsetMs: _int(data, 'offset_ms'),
        );
      case AppChannelTypes.agentActivity:
        return AgentActivityReceived(
          agent: _optionalString(data, 'agent') ?? _required(envelope.agent),
          task: _optionalString(data, 'task') ?? _required(envelope.task),
          state: _enumValue(data, 'state', const <String, AgentTaskState>{
            'working': AgentTaskState.working,
            'completed': AgentTaskState.completed,
            'failed': AgentTaskState.failed,
            'rejected': AgentTaskState.rejected,
          }),
          label: _optionalString(data, 'label'),
          detail: _optionalString(data, 'detail'),
        );
      case AppChannelTypes.plan:
        return PlanReceived(
          delegation: _string(data, 'delegation'),
          selected: _stringList(data, 'selected'),
          idle: _stringList(data, 'idle'),
        );
      case AppChannelTypes.a2ui:
        try {
          return A2uiEnvelopeReceived(
            message: A2uiDecoder.decode(data),
            raw: data,
            agent: envelope.agent,
            task: envelope.task,
          );
        } on A2uiDecodeException {
          throw const _Ignored(_Reasons.a2uiRefused);
        }
      default:
        throw const _Ignored(_Reasons.unknownType);
    }
  }

  static String _required(String? value) =>
      value ?? (throw const _Ignored(_Reasons.badField));

  static double _number(Map<String, Object?> data, String key) {
    final Object? value = data[key];
    if (value is num && !value.isNaN) return value.toDouble();
    throw const _Ignored(_Reasons.badField);
  }

  static int _int(Map<String, Object?> data, String key) {
    final Object? value = data[key];
    if (value is int) return value;
    throw const _Ignored(_Reasons.badField);
  }

  static String _string(Map<String, Object?> data, String key) {
    final Object? value = data[key];
    if (value is String) return value;
    throw const _Ignored(_Reasons.badField);
  }

  /// Tableau de chaînes obligatoire : absent, `null` ou mal typé, ignoré.
  static List<String> _stringList(Map<String, Object?> data, String key) {
    final Object? value = data[key];
    if (value is List<Object?> && value.every((Object? e) => e is String)) {
      return List<String>.of(value.cast<String>());
    }
    throw const _Ignored(_Reasons.badField);
  }

  /// Absent ou `null` : `null` ; présent mais d'un autre type : ignoré.
  static String? _optionalString(Map<String, Object?> data, String key) {
    final Object? value = data[key];
    if (value == null) return null;
    if (value is String) return value;
    throw const _Ignored(_Reasons.badField);
  }

  static T _enumValue<T>(
    Map<String, Object?> data,
    String key,
    Map<String, T> values,
  ) {
    final T? value = values[_string(data, key)];
    return value ?? (throw const _Ignored(_Reasons.unknownEnum));
  }
}

/// Signal interne : le message est ignoré pour [reason].
class _Ignored implements Exception {
  const _Ignored(this.reason);

  final String reason;
}
