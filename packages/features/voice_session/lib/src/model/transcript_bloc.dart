import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:entity_session/entity_session.dart';

/// Events de [TranscriptBloc].
sealed class TranscriptEvent {
  const TranscriptEvent();
}

/// Branche le Bloc sur une source d'événements de session.
final class TranscriptSourceSubscribed extends TranscriptEvent {
  const TranscriptSourceSubscribed(this.events);

  final Stream<SessionEvent> events;
}

/// La voix de l'IA est rétablie après une interruption : ses deltas
/// s'affichent de nouveau.
final class TranscriptResumed extends TranscriptEvent {
  const TranscriptResumed();
}

/// Les deux dernières répliques : une par rôle.
class TranscriptState {
  const TranscriptState({this.userLine = '', this.aiLine = ''});

  final String userLine;
  final String aiLine;

  @override
  bool operator ==(Object other) =>
      other is TranscriptState &&
      other.userLine == userLine &&
      other.aiLine == aiLine;

  @override
  int get hashCode => Object.hash(userLine, aiLine);

  @override
  String toString() => 'TranscriptState(user: $userLine, ai: $aiLine)';
}

/// Construit les deux lignes de transcription à partir des fragments reçus.
///
/// Les fragments d'un même rôle sont concaténés tels quels ; une réplique
/// repart du fragment reçu quand le rôle alterne. Pas de troncature (FR-19
/// est en J7).
class TranscriptBloc extends Bloc<TranscriptEvent, TranscriptState> {
  TranscriptBloc() : super(const TranscriptState()) {
    // Une nouvelle source remplace la précédente.
    on<TranscriptSourceSubscribed>(_onSubscribed, transformer: restartable());
    on<TranscriptResumed>(
      (event, emit) => _truncateFromMs = null,
      transformer: sequential(),
    );
  }

  // Début (horloge média) à partir duquel les fragments de l'IA sont écartés ;
  // `null` : aucune interruption en cours.
  int? _truncateFromMs;

  // Rôle du dernier fragment reçu ; `null` en début de session.
  TranscriptRole? _lastRole;

  Future<void> _onSubscribed(
    TranscriptSourceSubscribed event,
    Emitter<TranscriptState> emit,
  ) => emit.onEach<SessionEvent>(
    event.events,
    onData: (sessionEvent) {
      switch (sessionEvent) {
        case TranscriptDelta():
          final int? from = _truncateFromMs;
          if (from != null &&
              sessionEvent.role == TranscriptRole.ai &&
              sessionEvent.startMs >= from) {
            return;
          }
          _onDelta(sessionEvent, emit);
        case VoiceInterrupted(:final int atMs):
          _truncateFromMs = atMs;
        case SessionStateChanged(state: SessionState.closed) || ChannelLost():
          // Fin de session ou perte du canal : plus d'interruption en cours
          // (les lignes restent affichées).
          _truncateFromMs = null;
        case SessionStateChanged(state: SessionState.connecting):
          _lastRole = null;
          _truncateFromMs = null;
          emit(const TranscriptState());
        default:
          break;
      }
    },
  );

  void _onDelta(TranscriptDelta delta, Emitter<TranscriptState> emit) {
    final bool sameRole = _lastRole == delta.role;
    _lastRole = delta.role;
    emit(switch (delta.role) {
      TranscriptRole.user => TranscriptState(
        userLine: sameRole ? state.userLine + delta.text : delta.text,
        aiLine: state.aiLine,
      ),
      TranscriptRole.ai => TranscriptState(
        userLine: state.userLine,
        aiLine: sameRole ? state.aiLine + delta.text : delta.text,
      ),
    });
  }
}
