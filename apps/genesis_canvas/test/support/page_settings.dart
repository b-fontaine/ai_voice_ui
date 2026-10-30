import 'package:genesis_canvas/app/config/genesis_config.dart';
import 'package:genesis_canvas/pages/genesis_canvas/genesis_canvas_page_settings.dart';

/// Réglages de page issus d'une configuration (comme le fait `GenesisCanvasApp`).
GenesisCanvasPageSettings pageSettingsOf([
  GenesisConfig config = const GenesisConfig(),
]) => GenesisCanvasPageSettings(
  orbAttack: config.orbAttack,
  orbRelease: config.orbRelease,
  orbSilenceTimeout: config.orbSilenceTimeout,
  orbSpeakingThreshold: config.orbSpeakingThreshold,
  interruptResumeSilence: config.interruptResumeSilence,
  interruptMaxDuration: config.interruptMaxDuration,
  interruptStopSpan: config.interruptStopSpan,
  sessionCloseTimeout: config.sessionCloseTimeout,
  exitCloseTimeout: config.exitCloseTimeout,
  canvasResetRetries: config.canvasResetRetries,
  canvasResetRetryInterval: config.canvasResetRetryInterval,
  canvasActionRetries: config.canvasActionRetries,
  canvasActionRetryInterval: config.canvasActionRetryInterval,
  canvasActionMaxDuration: config.canvasActionMaxDuration,
  replayMaxGap: config.replayMaxGap,
  replayTick: config.replayTick,
  replayJournalMaxEntries: config.replayJournalMaxEntries,
  replayDefaultSpeed: config.replayDefaultSpeed,
  replayCaptureAt: config.replayCaptureAt,
);
