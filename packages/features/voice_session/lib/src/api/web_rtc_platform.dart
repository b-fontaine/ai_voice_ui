import 'dart:async';

/// Façade minimale de la plateforme WebRTC, écrite pour le besoin du
/// transport voix (et non réplique de l'API `flutter_webrtc`). C'est la
/// frontière mockable : la logique du transport se teste sans libwebrtc.
abstract interface class WebRtcPlatform {
  /// Ouvre **la** capture micro (écho, bruit et gain automatique activés).
  /// Lève si le micro est absent, refusé ou occupé.
  Future<RtcMic> openMic();

  /// Crée une connexion pair-à-pair vide.
  Future<RtcPeer> createPeer();
}

/// Capture micro ouverte.
abstract interface class RtcMic {
  /// Arrête les pistes audio puis libère le flux.
  Future<void> stop();
}

/// Connexion pair-à-pair, côté offreur.
abstract interface class RtcPeer {
  /// Ajoute les pistes audio de [mic] à la connexion.
  Future<void> addMic(RtcMic mic);

  /// Crée le canal de données [label], conservé ouvert et non lu. À appeler
  /// **avant** [createOfferWithGatheredCandidates].
  Future<void> createDataChannel(String label);

  /// Crée l'offre, l'applique en local, attend la fin de la collecte ICE
  /// (immédiat si déjà complète) puis renvoie le SDP local, candidats inclus.
  /// Lève [TimeoutException] si la collecte dépasse [iceTimeout].
  Future<String> createOfferWithGatheredCandidates(Duration iceTimeout);

  /// Applique l'answer SDP du relais.
  Future<void> setRemoteAnswer(String sdp);

  /// Ferme le canal de données puis la connexion.
  Future<void> close();

  /// Libère l'objet natif et son canal d'événements (que [close] ne libère
  /// pas). À appeler une seule fois, après [close].
  Future<void> dispose();
}
