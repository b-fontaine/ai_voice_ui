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
///
/// Tous portent [doneAction] : l'action dont la décision est en place
/// (bouton « fait », inactif, sans requête).
sealed class CanvasActionState {
  const CanvasActionState({this.doneAction});

  /// Action dont la décision est en place, s'il y en a une.
  final String? doneAction;

  /// Même état, avec une autre [doneAction].
  CanvasActionState withDoneAction(String? doneAction);
}

/// Aucune action en cours : les boutons sont actifs.
final class ActionIdle extends CanvasActionState {
  const ActionIdle({super.doneAction});

  @override
  ActionIdle withDoneAction(String? doneAction) =>
      ActionIdle(doneAction: doneAction);
}

/// L'action [name] est en cours d'envoi (réessais compris).
final class ActionSending extends CanvasActionState {
  const ActionSending(this.name, {super.doneAction});

  final String name;

  @override
  ActionSending withDoneAction(String? doneAction) =>
      ActionSending(name, doneAction: doneAction);
}

/// L'action [name] est acceptée ; l'agent travaille.
final class ActionRunning extends CanvasActionState {
  const ActionRunning(this.name, {super.doneAction});

  final String name;

  @override
  ActionRunning withDoneAction(String? doneAction) =>
      ActionRunning(name, doneAction: doneAction);
}

/// L'action n'a pas abouti ; l'état suivant est aussitôt [ActionIdle].
final class ActionFailed extends CanvasActionState {
  const ActionFailed(this.reason, {super.doneAction});

  final CanvasActionFailure reason;

  @override
  ActionFailed withDoneAction(String? doneAction) =>
      ActionFailed(reason, doneAction: doneAction);
}
