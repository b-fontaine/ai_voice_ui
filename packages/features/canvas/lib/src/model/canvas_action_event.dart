/// Événements du `CanvasActionBloc`.
sealed class CanvasActionEvent {
  const CanvasActionEvent();
}

/// Clic sur une action d'une Barre d'actions : [name] est l'identifiant de
/// l'action (`block_release`…), [surfaceId] la surface qui la porte.
final class ActionRequested extends CanvasActionEvent {
  const ActionRequested(this.name, this.surfaceId);

  final String name;
  final String surfaceId;
}

/// Changement d'activité des agents, relayé par la page : [busy] vaut `true`
/// tant qu'au moins un agent travaille ou est attendu.
final class ActionActivityChanged extends CanvasActionEvent {
  const ActionActivityChanged({required this.busy});

  final bool busy;
}

/// La session voix est close : plus rien n'arrivera pour l'action en cours.
final class ActionSessionClosed extends CanvasActionEvent {
  const ActionSessionClosed();
}

/// Remise à vide de la scène : l'action en cours est abandonnée.
final class ActionStageReset extends CanvasActionEvent {
  const ActionStageReset();
}
