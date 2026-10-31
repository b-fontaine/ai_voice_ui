import 'package:flutter/foundation.dart' show immutable;

/// Réglages de la page, construits par la couche `app` à partir de la
/// configuration de lancement et reçus par constructeur (la page n'importe
/// rien de la couche supérieure).
@immutable
class GenesisCanvasPageSettings {
  const GenesisCanvasPageSettings({
    required this.orbAttack,
    required this.orbRelease,
    required this.orbSilenceTimeout,
    required this.orbSpeakingThreshold,
    required this.interruptResumeSilence,
    required this.interruptMaxDuration,
    required this.interruptStopSpan,
    required this.sessionCloseTimeout,
    required this.exitCloseTimeout,
    required this.canvasResetRetries,
    required this.canvasResetRetryInterval,
    required this.canvasActionRetries,
    required this.canvasActionRetryInterval,
    required this.canvasActionMaxDuration,
    required this.replayJournalMaxEntries,
    required this.replayTick,
    required this.replayMaxGap,
    required this.replayDefaultSpeed,
    this.replayCaptureAt,
  });

  /// Temps de montée du lissage de l'orbe.
  final Duration orbAttack;

  /// Temps de descente du lissage de l'orbe.
  final Duration orbRelease;

  /// Silence au-delà duquel l'orbe retombe au repos.
  final Duration orbSilenceTimeout;

  /// Niveau lissé à partir duquel l'orbe est dite « parle ».
  final double orbSpeakingThreshold;

  /// Silence de l'IA qui met fin à une interruption vocale.
  final Duration interruptResumeSilence;

  /// Durée maximale d'une interruption vocale.
  final Duration interruptMaxDuration;

  /// Écart maximal entre la coupure et la délégation du « Stop » lui-même.
  final Duration interruptStopSpan;

  /// Délai maximal d'arrêt et de libération de la session à la fermeture.
  final Duration sessionCloseTimeout;

  /// Délai maximal d'attente de l'arrêt de la session à la sortie de l'app.
  final Duration exitCloseTimeout;

  /// Nombre de réessais de la remise à vide quand le backend est occupé.
  final int canvasResetRetries;

  /// Intervalle entre deux réessais de la remise à vide.
  final Duration canvasResetRetryInterval;

  /// Nombre de réessais d'une action quand le backend est occupé.
  final int canvasActionRetries;

  /// Intervalle entre deux essais d'une action.
  final Duration canvasActionRetryInterval;

  /// Durée maximale de l'état « en cours » d'une action.
  final Duration canvasActionMaxDuration;

  /// Plafond du journal des messages A2UI (rejeu, acte 4) : au-delà, il cesse
  /// d'enregistrer.
  final int replayJournalMaxEntries;

  /// Pas de l'horloge du lecteur de rejeu.
  final Duration replayTick;

  /// Écart maximal conservé entre deux messages rejoués (valeur à 1x).
  final Duration replayMaxGap;

  /// Vitesse du rejeu au premier démarrage.
  final double replayDefaultSpeed;

  /// Mode scénario avec capture : fraction (0 à 1) de la durée comprimée du
  /// rejeu où se placer avant la capture ; `null` : pas de rejeu avant la
  /// capture.
  final double? replayCaptureAt;

  @override
  bool operator ==(Object other) =>
      other is GenesisCanvasPageSettings &&
      other.orbAttack == orbAttack &&
      other.orbRelease == orbRelease &&
      other.orbSilenceTimeout == orbSilenceTimeout &&
      other.orbSpeakingThreshold == orbSpeakingThreshold &&
      other.interruptResumeSilence == interruptResumeSilence &&
      other.interruptMaxDuration == interruptMaxDuration &&
      other.interruptStopSpan == interruptStopSpan &&
      other.sessionCloseTimeout == sessionCloseTimeout &&
      other.exitCloseTimeout == exitCloseTimeout &&
      other.canvasResetRetries == canvasResetRetries &&
      other.canvasResetRetryInterval == canvasResetRetryInterval &&
      other.canvasActionRetries == canvasActionRetries &&
      other.canvasActionRetryInterval == canvasActionRetryInterval &&
      other.canvasActionMaxDuration == canvasActionMaxDuration &&
      other.replayJournalMaxEntries == replayJournalMaxEntries &&
      other.replayTick == replayTick &&
      other.replayMaxGap == replayMaxGap &&
      other.replayDefaultSpeed == replayDefaultSpeed &&
      other.replayCaptureAt == replayCaptureAt;

  @override
  int get hashCode => Object.hash(
    orbAttack,
    orbRelease,
    orbSilenceTimeout,
    orbSpeakingThreshold,
    interruptResumeSilence,
    interruptMaxDuration,
    interruptStopSpan,
    sessionCloseTimeout,
    exitCloseTimeout,
    canvasResetRetries,
    canvasResetRetryInterval,
    canvasActionRetries,
    canvasActionRetryInterval,
    canvasActionMaxDuration,
    replayJournalMaxEntries,
    replayTick,
    replayMaxGap,
    replayDefaultSpeed,
    replayCaptureAt,
  );
}
