import 'package:feature_voice_session/feature_voice_session.dart';

/// Message affiché pour un échec de session voix. Texte fixe en français :
/// aucun détail brut ni URL (le modèle ne porte que des causes fermées).
String voiceFailureMessage(VoiceFailure failure) => switch (failure) {
  BackendUnreachable() => 'Backend injoignable',
  RateLimited(:final retryAfter) =>
    retryAfter == null
        ? 'Trop de demandes'
        : 'Trop de demandes, réessayez dans ${_seconds(retryAfter)} s',
  RelayFailed() => 'Le relais a échoué',
  MicUnavailable() => 'Micro indisponible',
  IceTimeout() => 'Connexion WebRTC trop lente',
  ConnectionLost() => 'Connexion perdue',
  SessionClosed(:final reason) => _closedMessage(reason),
};

// Raisons du contrat : textes fixes. Toute autre valeur reçue du backend est
// ignorée, jamais affichée.
String _closedMessage(String? reason) => switch (reason) {
  'expired' => 'Session expirée',
  'max_session' => 'Durée maximale de la session atteinte',
  'remote_hangup' => 'Session terminée par le service',
  'attach_failed' => 'Session indisponible',
  'connection_lost' => 'Connexion perdue',
  'content' => 'Session terminée (contenu refusé)',
  _ => 'Session terminée',
};

// Arrondi à la seconde supérieure, au moins 1 s.
int _seconds(Duration d) {
  final seconds = (d.inMilliseconds / 1000).ceil();
  return seconds < 1 ? 1 : seconds;
}
