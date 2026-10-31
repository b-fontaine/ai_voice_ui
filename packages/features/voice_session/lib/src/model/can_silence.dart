import 'orb_phase_bloc.dart';
import 'voice_session_status.dart';

/// « Faire taire » est actif quand la session est [Active] et que l'orbe n'est
/// pas déjà [Interrupted]. Règle unique du bouton et du raccourci Échap.
bool canSilence(VoiceSessionStatus status, OrbPhase phase) =>
    status is Active && phase is! Interrupted;
