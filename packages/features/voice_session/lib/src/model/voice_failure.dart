/// Cause, fermée, de l'échec d'une session voix. Les textes affichés sont du
/// ressort de l'interface, pas du modèle.
sealed class VoiceFailure {
  const VoiceFailure();
}

/// Le backend est injoignable (connexion refusée, délai dépassé).
final class BackendUnreachable extends VoiceFailure {
  const BackendUnreachable();

  @override
  bool operator ==(Object other) => other is BackendUnreachable;

  @override
  int get hashCode => (BackendUnreachable).hashCode;

  @override
  String toString() => 'BackendUnreachable';
}

/// Trop de sessions (429) ; [retryAfter] vient de `Retry-After`, sinon `null`.
final class RateLimited extends VoiceFailure {
  const RateLimited(this.retryAfter);

  final Duration? retryAfter;

  @override
  bool operator ==(Object other) =>
      other is RateLimited && other.retryAfter == retryAfter;

  @override
  int get hashCode => Object.hash(RateLimited, retryAfter);

  @override
  String toString() => 'RateLimited($retryAfter)';
}

/// Le relais a échoué (502, requête refusée, answer inutilisable).
final class RelayFailed extends VoiceFailure {
  const RelayFailed();

  @override
  bool operator ==(Object other) => other is RelayFailed;

  @override
  int get hashCode => (RelayFailed).hashCode;

  @override
  String toString() => 'RelayFailed';
}

/// Micro indisponible.
final class MicUnavailable extends VoiceFailure {
  const MicUnavailable();

  @override
  bool operator ==(Object other) => other is MicUnavailable;

  @override
  int get hashCode => (MicUnavailable).hashCode;

  @override
  String toString() => 'MicUnavailable';
}

/// Collecte ICE trop longue.
final class IceTimeout extends VoiceFailure {
  const IceTimeout();

  @override
  bool operator ==(Object other) => other is IceTimeout;

  @override
  int get hashCode => (IceTimeout).hashCode;

  @override
  String toString() => 'IceTimeout';
}

/// Le canal de la session s'est coupé en cours de session.
final class ConnectionLost extends VoiceFailure {
  const ConnectionLost();

  @override
  bool operator ==(Object other) => other is ConnectionLost;

  @override
  int get hashCode => (ConnectionLost).hashCode;

  @override
  String toString() => 'ConnectionLost';
}

/// La session est terminée côté backend ; [reason] vient de `session.state`
/// (`closed`), sinon `null`.
final class SessionClosed extends VoiceFailure {
  const SessionClosed(this.reason);

  final String? reason;

  @override
  bool operator ==(Object other) =>
      other is SessionClosed && other.reason == reason;

  @override
  int get hashCode => Object.hash(SessionClosed, reason);

  @override
  String toString() => 'SessionClosed($reason)';
}
