/// Cause, fermée, d'un échec du transport voix.
enum VoiceTransportFailure {
  /// Micro absent, refusé ou déjà occupé.
  micUnavailable,

  /// La collecte des candidats ICE n'a pas abouti dans le délai.
  iceTimeout,

  /// Tout autre échec du transport (connexion, answer refusée).
  failed,
}

/// Échec du transport voix, avec une cause fermée. Le message ne contient
/// aucun SDP ni détail de la plateforme.
class VoiceTransportException implements Exception {
  const VoiceTransportException(this.kind);

  final VoiceTransportFailure kind;

  @override
  String toString() => 'VoiceTransportException(${kind.name})';
}

/// Port du transport voix (micro et connexion WebRTC), frontière de la
/// plateforme. Une instance sert à **un seul** démarrage : une connexion
/// fermée ne se réutilise pas.
abstract interface class VoiceTransport {
  /// Acquiert le micro, crée le canal d'événements puis l'offre, et renvoie
  /// le SDP local une fois l'ICE complète. Lève [VoiceTransportException].
  Future<String> createOfferSdp();

  /// Applique l'answer SDP du relais. Lève [VoiceTransportException].
  Future<void> applyAnswer(String sdp);

  /// Arrête la capture et ferme la connexion. Ne lève pas.
  Future<void> stop();

  /// Libère les ressources restantes, après [stop].
  Future<void> dispose();
}
