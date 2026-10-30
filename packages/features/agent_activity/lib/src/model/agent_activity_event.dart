import 'package:entity_session/entity_session.dart';

/// Events de `AgentActivityBloc`.
sealed class AgentActivityEvent {
  const AgentActivityEvent();
}

/// Branche le Bloc sur une source d'événements de session.
final class AgentActivitySourceSubscribed extends AgentActivityEvent {
  const AgentActivitySourceSubscribed(this.events);

  final Stream<SessionEvent> events;
}

/// Commande : remise à vide du rail (état initial). Utilisée par la remise à
/// vide de l'écran.
final class AgentActivityReset extends AgentActivityEvent {
  const AgentActivityReset();
}
