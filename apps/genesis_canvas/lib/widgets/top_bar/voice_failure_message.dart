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
  SessionClosed(:final reason) =>
    reason == 'expired'
        ? 'Session expirée'
        : reason == null
        ? 'Session terminée'
        : 'Session terminée ($reason)',
};

// Arrondi à la seconde supérieure, au moins 1 s.
int _seconds(Duration d) {
  final seconds = (d.inMilliseconds / 1000).ceil();
  return seconds < 1 ? 1 : seconds;
}
