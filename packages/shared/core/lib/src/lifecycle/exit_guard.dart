import 'dart:async';
import 'dart:ui' show AppExitResponse;

/// Retient la sortie de l'app le temps d'arrêter la session voix, de façon
/// bornée : la fermeture de la fenêtre ne doit ni laisser de session
/// orpheline ni bloquer l'utilisateur.
///
/// [stop] est typiquement `VoiceSession.stop`, qui n'est pas borné pendant
/// `Connecting` : c'est [timeout] qui couvre ce cas.
class ExitGuard {
  const ExitGuard(this._stop, this._timeout);

  final Future<void> Function() _stop;
  final Duration _timeout;

  /// Attend [_stop] au plus [_timeout], puis répond toujours `exit`, même si
  /// l'arrêt échoue ou dépasse le délai.
  Future<AppExitResponse> onExitRequested() async {
    try {
      await _stop().timeout(_timeout);
    } on Object {
      // Délai dépassé ou échec : la sortie prime, la libération est au mieux.
    }
    return AppExitResponse.exit;
  }
}
