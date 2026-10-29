import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:feature_voice_session/feature_voice_session.dart';

/// Substitut de `VoiceSessionBloc` pour tester les widgets : l'état est posé
/// à la demande par le test (frontière : la vraie machine à états
/// `VoiceSession` est couverte par ses propres tests et l'acceptation V1-V5)
/// et les commandes reçues sont enregistrées.
///
/// `implements VoiceSessionBloc` : le type fourni à `BlocProvider` est bien
/// celui que les widgets lisent, sans construire de `VoiceSession`.
class StubVoiceSessionBloc extends Bloc<VoiceSessionEvent, VoiceSessionStatus>
    implements VoiceSessionBloc {
  StubVoiceSessionBloc([super.initialState = const Idle()]) {
    on<VoiceSessionStarted>((event, _) => received.add(event));
    on<VoiceSessionStopped>((event, _) => received.add(event));
    on<VoiceSessionSubscribed>((event, _) => received.add(event));
  }

  /// Événements reçus des widgets, dans l'ordre.
  final List<VoiceSessionEvent> received = <VoiceSessionEvent>[];

  /// Pose un nouveau statut (équivalent d'un statut émis par la session).
  void setStatus(VoiceSessionStatus status) => emit(status);
}
