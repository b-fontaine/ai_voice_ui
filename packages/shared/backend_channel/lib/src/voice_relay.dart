/// Réponse du relais à la création d'une session voix.
class RelayAnswer {
  const RelayAnswer({required this.answerSdp, required this.sessionId});

  /// Answer SDP à appliquer à la connexion WebRTC.
  final String answerSdp;

  /// Identifiant de session (`X-Session-Id`), `[A-Za-z0-9_-]{1,128}`.
  final String sessionId;

  @override
  bool operator ==(Object other) =>
      other is RelayAnswer &&
      other.answerSdp == answerSdp &&
      other.sessionId == sessionId;

  @override
  int get hashCode => Object.hash(answerSdp, sessionId);

  /// Ni SDP ni identifiant : ils ne doivent pas finir dans un journal.
  @override
  String toString() => 'RelayAnswer';
}

/// Cause fermée d'un échec du relais voix.
enum RelayFailureKind {
  /// Backend injoignable (connexion refusée, coupée, TLS).
  unreachable,

  /// Délai de la requête dépassé.
  timeout,

  /// 429 : trop de sessions ; voir [RelayFailure.retryAfter].
  rateLimited,

  /// 400, 413 ou 415 : requête refusée.
  badRequest,

  /// 502 et autres 5xx : le relais OpenAI a échoué.
  relayFailed,

  /// 504 sur `DELETE` : la fermeture n'est pas confirmée.
  closeNotConfirmed,

  /// 404 sur `DELETE` : session inconnue.
  sessionNotFound,

  /// Réponse hors contrat (identifiant absent ou invalide, corps vide ou
  /// trop gros, statut inattendu).
  protocol,
}

/// Échec du relais voix. Le message ne contient ni URL, ni SDP, ni corps de
/// réponse.
class RelayFailure implements Exception {
  const RelayFailure(this.kind, {this.retryAfter});

  final RelayFailureKind kind;

  /// Délai suggéré par `Retry-After` (1 à 3600 s), sinon `null`.
  final Duration? retryAfter;

  String get message => 'Relais voix en échec : ${kind.name}';

  @override
  String toString() => 'RelayFailure(${kind.name})';
}

/// Port du relais voix du backend : crée et ferme une session WebRTC.
abstract interface class VoiceRelay {
  /// Envoie l'offre SDP et renvoie l'answer et l'identifiant de session.
  ///
  /// Lève [RelayFailure].
  Future<RelayAnswer> createSession(String offerSdp);

  /// Ferme la session côté relais. Lève [RelayFailure], et [ArgumentError]
  /// si [sessionId] est invalide.
  Future<void> deleteSession(String sessionId);
}
