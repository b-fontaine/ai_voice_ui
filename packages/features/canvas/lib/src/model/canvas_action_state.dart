/// Cause fermée d'un échec d'action (jamais le détail brut du backend).
enum CanvasActionFailure {
  /// Backend occupé, réessais épuisés.
  busy,

  /// Aucune session voix ouverte, réessais épuisés.
  noSession,

  /// Demande refusée par le backend.
  rejected,

  /// Backend injoignable ou réponse inexploitable.
  unreachable,
}

/// États du `CanvasActionBloc`. Les boutons ne sont actifs qu'à l'état [ActionIdle].
sealed class CanvasActionState {
  const CanvasActionState();
}

/// Aucune action en cours : les boutons sont actifs.
final class ActionIdle extends CanvasActionState {
  const ActionIdle();
}

/// L'action [name] est en cours d'envoi (réessais compris).
final class ActionSending extends CanvasActionState {
  const ActionSending(this.name);

  final String name;
}

/// L'action [name] est acceptée ; l'agent travaille.
final class ActionRunning extends CanvasActionState {
  const ActionRunning(this.name);

  final String name;
}

/// L'action n'a pas abouti ; l'état suivant est aussitôt [ActionIdle].
final class ActionFailed extends CanvasActionState {
  const ActionFailed(this.reason);

  final CanvasActionFailure reason;
}
