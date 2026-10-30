import 'app_channel_envelope.dart';

/// Cause, fermée, de l'échec du canal app.
enum AppChannelFailureKind {
  /// Connexion impossible : serveur arrêté, délai dépassé, réseau.
  unreachable,

  /// 404 : la session est inconnue ou déjà terminée.
  sessionNotFound,

  /// 400 : requête refusée par le backend (identifiant invalide).
  badRequest,

  /// 421 : l'hôte de `baseUrl` n'est pas accepté par le backend.
  hostRejected,

  /// Fermeture 1008 : l'abonné lisait trop lentement.
  tooSlow,

  /// Connexion établie puis coupée de façon anormale.
  connectionLost,
}

/// Échec du canal app. Le message est une phrase fermée : il ne reprend ni
/// l'URL, ni l'hôte, ni le contenu reçu.
class AppChannelFailure implements Exception {
  const AppChannelFailure(this.kind);

  final AppChannelFailureKind kind;

  @override
  String toString() => 'AppChannelFailure: ${kind.name}';
}

/// Port du canal WSS `/app` du backend (contrat v1).
abstract interface class AppChannel {
  /// Ouvre le canal de la session [sessionId] à l'écoute du flux.
  ///
  /// Le flux émet les enveloppes valides dans l'ordre (le backlog d'abord).
  /// Une fermeture normale du serveur le termine sans erreur ; tout autre
  /// échec émet une seule [AppChannelFailure] puis le termine. Annuler
  /// l'abonnement ferme la connexion.
  ///
  /// Lève [ArgumentError] si [sessionId] ne respecte pas
  /// `[A-Za-z0-9_-]{1,128}`.
  Stream<AppChannelEnvelope> open(String sessionId);
}
