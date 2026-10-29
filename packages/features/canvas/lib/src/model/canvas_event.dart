import 'package:a2ui_core/a2ui_core.dart' show A2uiMessage;

/// Événements du `CanvasBloc`.
sealed class CanvasEvent {
  const CanvasEvent();
}

/// Commande ponctuelle, traitée dans l'ordre d'arrivée (`sequential`).
sealed class CanvasCommand extends CanvasEvent {
  const CanvasCommand();
}

/// Souscription à une source de messages A2UI décodés : le Bloc consomme
/// le flux, l'annule à la fermeture ou si une nouvelle source arrive.
final class CanvasSourceSubscribed extends CanvasEvent {
  const CanvasSourceSubscribed(this.messages);
  final Stream<A2uiMessage> messages;
}

/// Remise à vide du canevas (toutes les surfaces sont supprimées du moteur).
final class CanvasResetRequested extends CanvasCommand {
  const CanvasResetRequested();
}

/// Un message A2UI v0.9 décodé à appliquer au moteur genui.
///
/// Le Bloc déduit les changements de surface et de phase du type du message.
final class A2uiMessageReceived extends CanvasCommand {
  const A2uiMessageReceived(this.message);
  final A2uiMessage message;
}
