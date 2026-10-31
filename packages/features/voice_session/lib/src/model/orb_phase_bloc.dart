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

/// L'IA a été coupée (`voice.interrupted` ou silence local).
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

// Délai de reprise ou durée maximale écoulé (posé par les minuteries) ;
// [generation] numérote l'interruption qui l'a armé : une échéance déjà en
// file ne termine pas une interruption plus récente.
final class _InterruptionEnded extends OrbPhaseEvent {
  const _InterruptionEnded(this.generation);

  final int generation;
}

// Nature de l'interruption en cours.
enum _InterruptionKind { stop, silence, correction, overlap }

/// Phase de l'orbe : `Listening | Speaking | Interrupted`.
///
/// `VoiceInterrupted` et `VoiceSilenced` passent en [Interrupted]. On en sort quand `orb.level`
/// reste sous [speakingThreshold] pendant [resumeSilence] (un niveau au-dessus
/// du seuil repousse l'échéance), au bout de [maxInterruption], à la
/// délégation suivante ou à la fin de la session (`closed`, `connecting`,
/// [ChannelLost]). Une délégation datée au plus de [stopSpan] après la coupure
/// est celle du « Stop » lui-même : elle n'y met pas fin. Après un silence
/// local, aucune délégation n'est exemptée. Après une interruption de cause
/// `correction` ou `overlap`, la première délégation datée au plus tôt de
/// `at_ms` (celle de la correction) met fin à l'interruption. Un `overlap` reçu
/// alors que la phase n'est pas [Speaking] (le fournisseur a déjà coupé sa
/// voix) donne [Interrupted] puis [Listening] aussitôt (règle P6). Pendant l'interruption, le
/// niveau ne fait pas passer en [Speaking] : la voix de l'IA est coupée. Si la
/// délégation de la correction est arrivée avant `voice.interrupted`, le Bloc
/// émet [Interrupted] puis [Listening] aussitôt.
///
/// Le Bloc ne rétablit pas lui-même le son : la page de composition relie le
/// retour hors de [Interrupted] à `VoiceSession.resumeRemoteAudio`.
class OrbPhaseBloc extends Bloc<OrbPhaseEvent, OrbPhase> {
  OrbPhaseBloc({
    required this.speakingThreshold,
    required this.resumeSilence,
    required this.maxInterruption,
    required this.stopSpan,
  }) : super(const Listening()) {
    // Une nouvelle source remplace la précédente.
    on<OrbPhaseSourceSubscribed>(_onSubscribed, transformer: restartable());
    on<_InterruptionEnded>((event, emit) {
      if (event.generation == _generation) _endInterruption(emit);
    }, transformer: sequential());
  }

  /// Niveau (0..1) à partir duquel l'IA est dite « parle ».
  final double speakingThreshold;

  /// Silence qui met fin à l'interruption.
  final Duration resumeSilence;

  /// Durée au bout de laquelle l'interruption prend fin quoi qu'il arrive.
  final Duration maxInterruption;

  /// Écart maximal entre la coupure et la délégation que crée le « Stop »
  /// lui-même (même réglage que `VOICE_STOP_SPAN` côté backend).
  final Duration stopSpan;

  // Numéro de l'interruption en cours ; incrémenté à chaque fin ou début.
  int _generation = 0;
  int _interruptedAtMs = 0;
  // Nature de l'interruption en cours : `stop` exempte la délégation du « Stop »
  // lui-même ; `correction` et `overlap` attendent la délégation d'offset
  // >= `at_ms` ; `silence` s'achève à la première délégation.
  _InterruptionKind _kind = _InterruptionKind.silence;
  // Plus grand offset de `DelegationStarted` reçu depuis le début de la session.
  int? _lastDelegationOffsetMs;

  Timer? _silenceTimer;
  Timer? _maxTimer;

  Future<void> _onSubscribed(
    OrbPhaseSourceSubscribed event,
    Emitter<OrbPhase> emit,
  ) => emit.onEach<SessionEvent>(
    event.events,
    onData: (sessionEvent) {
      switch (sessionEvent) {
        case VoiceInterrupted(:final int atMs, :final InterruptionCause cause):
          // Hors de la parole de l'IA, le fournisseur a déjà coupé sa voix
          // avant le message (règle P6) : le chevauchement n'a plus rien à
          // couper et la piste doit être rétablie aussitôt.
          final bool overlapOutsideSpeech =
              cause == InterruptionCause.overlap && state is! Speaking;
          _beginInterruption(
            emit,
            atMs: atMs,
            kind: switch (cause) {
              InterruptionCause.stop => _InterruptionKind.stop,
              InterruptionCause.correction => _InterruptionKind.correction,
              InterruptionCause.overlap => _InterruptionKind.overlap,
            },
          );
          // La délégation de la correction (ou du chevauchement) a pu arriver
          // avant l'interruption : on passe par Interrupted (la page coupe la
          // piste) puis on en sort aussitôt (la page la rétablit).
          final int? lastOffset = _lastDelegationOffsetMs;
          final bool delegatedAlready =
              cause != InterruptionCause.stop &&
              lastOffset != null &&
              lastOffset >= atMs;
          if (overlapOutsideSpeech || delegatedAlready) {
            _endInterruption(emit);
          }
        case VoiceSilenced():
          _beginInterruption(emit, atMs: 0, kind: _InterruptionKind.silence);
        case OrbLevelChanged(:final double level):
          final bool loud = level >= speakingThreshold;
          if (state is Interrupted) {
            if (loud) _armSilence();
          } else {
            emit(loud ? const Speaking() : const Listening());
          }
        case DelegationStarted(:final int offsetMs):
          if (_lastDelegationOffsetMs == null ||
              offsetMs > _lastDelegationOffsetMs!) {
            _lastDelegationOffsetMs = offsetMs;
          }
          if (state is! Interrupted) {
            _endInterruption(emit);
          } else {
            final bool ends = switch (_kind) {
              _InterruptionKind.stop =>
                offsetMs > _interruptedAtMs + stopSpan.inMilliseconds,
              _InterruptionKind.correction ||
              _InterruptionKind.overlap => offsetMs >= _interruptedAtMs,
              _InterruptionKind.silence => true,
            };
            if (ends) _endInterruption(emit);
          }
        case SessionStateChanged(state: SessionState.closed) ||
            SessionStateChanged(state: SessionState.connecting) ||
            ChannelLost():
          _lastDelegationOffsetMs = null;
          _endInterruption(emit);
        default:
          break;
      }
    },
  );

  void _beginInterruption(
    Emitter<OrbPhase> emit, {
    required int atMs,
    required _InterruptionKind kind,
  }) {
    _maxTimer?.cancel();
    _generation++;
    _interruptedAtMs = atMs;
    _kind = kind;
    final int generation = _generation;
    _maxTimer = Timer(maxInterruption, () => _signalEnd(generation));
    _armSilence();
    emit(const Interrupted());
  }

  void _armSilence() {
    _silenceTimer?.cancel();
    final int generation = _generation;
    _silenceTimer = Timer(resumeSilence, () => _signalEnd(generation));
  }

  void _signalEnd(int generation) {
    if (!isClosed) add(_InterruptionEnded(generation));
  }

  void _endInterruption(Emitter<OrbPhase> emit) {
    _generation++;
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
