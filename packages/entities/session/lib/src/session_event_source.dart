import 'session_event.dart';

/// Port : source des événements de la session en cours.
abstract interface class SessionEventSource {
  Stream<SessionEvent> get events;
}
