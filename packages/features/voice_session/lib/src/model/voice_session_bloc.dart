import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';

import 'voice_session.dart';
import 'voice_session_status.dart';

/// Events de [VoiceSessionBloc].
sealed class VoiceSessionEvent {
  const VoiceSessionEvent();
}

/// Branche le Bloc sur le flux de statuts de la session.
final class VoiceSessionSubscribed extends VoiceSessionEvent {
  const VoiceSessionSubscribed();
}

/// Demande de démarrage.
final class VoiceSessionStarted extends VoiceSessionEvent {
  const VoiceSessionStarted();
}

/// Demande d'arrêt.
final class VoiceSessionStopped extends VoiceSessionEvent {
  const VoiceSessionStopped();
}

/// Bloc mince : son état EST le [VoiceSessionStatus] de la [VoiceSession],
/// qui reste l'unique machine à états. Il ne la possède pas : [close] ne
/// l'élimine pas (propriété de la page).
class VoiceSessionBloc extends Bloc<VoiceSessionEvent, VoiceSessionStatus> {
  VoiceSessionBloc(this._session) : super(const Idle()) {
    // Un nouvel abonnement remplace le précédent.
    on<VoiceSessionSubscribed>(_onSubscribed, transformer: restartable());
    // Une commande pendant l'exécution de la précédente est ignorée.
    on<VoiceSessionStarted>(
      (_, _) => _session.start(),
      transformer: droppable(),
    );
    on<VoiceSessionStopped>(
      (_, _) => _session.stop(),
      transformer: droppable(),
    );
  }

  final VoiceSession _session;

  Future<void> _onSubscribed(
    VoiceSessionSubscribed event,
    Emitter<VoiceSessionStatus> emit,
  ) => emit.forEach<VoiceSessionStatus>(
    _session.status,
    onData: (status) => status,
  );
}
