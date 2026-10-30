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
  sessionCloseTimeout: config.sessionCloseTimeout,
  exitCloseTimeout: config.exitCloseTimeout,
);
