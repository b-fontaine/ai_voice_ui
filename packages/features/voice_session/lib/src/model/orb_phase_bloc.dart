import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:entity_session/entity_session.dart';

/// Phase de l'orbe vocale (FR-19, RG-17). Distincte de `VoiceSessionStatus` :
/// elle décrit la voix de l'IA, pas la connexion.
sealed class OrbPhase {
  const OrbPhase();
}

/// Rien ne sort de la voix de l'IA.
final class Listening extends OrbPhase {
  const Listening();
}

/// La voix de l'IA est audible.
final class Speaking extends OrbPhase {
  const Speaking();
}

/// L'IA a été coupée (`voice.interrupted`).
final class Interrupted extends OrbPhase {
  const Interrupted();
}

/// Events de [OrbPhaseBloc].
sealed class OrbPhaseEvent {
  const OrbPhaseEvent();
}

/// Branche le Bloc sur une source d'événements de session.
final class OrbPhaseSourceSubscribed extends OrbPhaseEvent {
  const OrbPhaseSourceSubscribed(this.events);

  final Stream<SessionEvent> events;
}

// Délai de reprise ou durée maximale écoulé (posé par les minuteries).
final class _InterruptionEnded extends OrbPhaseEvent {
  const _InterruptionEnded();
}

/// Phase de l'orbe : `Listening | Speaking | Interrupted`.
///
/// `VoiceInterrupted` passe en [Interrupted]. On en sort quand `orb.level`
/// reste sous [speakingThreshold] pendant [resumeSilence] (un niveau au-dessus
/// du seuil repousse l'échéance), au bout de [maxInterruption], à la
/// délégation suivante ou à la fin de la session. Pendant l'interruption, le
/// niveau ne fait pas passer en [Speaking] : la voix de l'IA est coupée.
///
/// Le Bloc ne rétablit pas lui-même le son : la page de composition relie le
/// retour hors de [Interrupted] à `VoiceSession.resumeRemoteAudio`.
class OrbPhaseBloc extends Bloc<OrbPhaseEvent, OrbPhase> {
  OrbPhaseBloc({
    required this.speakingThreshold,
    required this.resumeSilence,
    required this.maxInterruption,
  }) : super(const Listening()) {
    // Une nouvelle source remplace la précédente.
    on<OrbPhaseSourceSubscribed>(_onSubscribed, transformer: restartable());
    on<_InterruptionEnded>(
      (event, emit) => _endInterruption(emit),
      transformer: sequential(),
    );
  }

  /// Niveau (0..1) à partir duquel l'IA est dite « parle ».
  final double speakingThreshold;

  /// Silence qui met fin à l'interruption.
  final Duration resumeSilence;

  /// Durée au bout de laquelle l'interruption prend fin quoi qu'il arrive.
  final Duration maxInterruption;

  Timer? _silenceTimer;
  Timer? _maxTimer;

  Future<void> _onSubscribed(
    OrbPhaseSourceSubscribed event,
    Emitter<OrbPhase> emit,
  ) => emit.onEach<SessionEvent>(
    event.events,
    onData: (sessionEvent) {
      switch (sessionEvent) {
        case VoiceInterrupted():
          _maxTimer?.cancel();
          _maxTimer = Timer(maxInterruption, _signalEnd);
          _armSilence();
          emit(const Interrupted());
        case OrbLevelChanged(:final double level):
          final bool loud = level >= speakingThreshold;
          if (state is Interrupted) {
            if (loud) _armSilence();
          } else {
            emit(loud ? const Speaking() : const Listening());
          }
        case DelegationStarted():
          _endInterruption(emit);
        case SessionStateChanged(state: SessionState.closed) ||
            SessionStateChanged(state: SessionState.connecting):
          _endInterruption(emit);
        default:
          break;
      }
    },
  );

  void _armSilence() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(resumeSilence, _signalEnd);
  }

  void _signalEnd() {
    if (!isClosed) add(const _InterruptionEnded());
  }

  void _endInterruption(Emitter<OrbPhase> emit) {
    _cancelTimers();
    if (state is Interrupted) emit(const Listening());
  }

  void _cancelTimers() {
    _silenceTimer?.cancel();
    _maxTimer?.cancel();
    _silenceTimer = _maxTimer = null;
  }

  @override
  Future<void> close() {
    _cancelTimers();
    return super.close();
  }
}
