/// Événements de la régie de scène.
sealed class StageEvent {
  const StageEvent();
}

/// Passe à l'acte suivant ; de l'acte 3, retour cyclique à l'acte 1.
final class StageActAdvanced extends StageEvent {
  const StageActAdvanced();
}

/// Remise à vide : retour à l'acte 1.
final class StageResetRequested extends StageEvent {
  const StageResetRequested();
}

/// Avance automatique : l'acte [act] vient d'être atteint (action exécutée).
///
/// Monotone : l'état devient `max(acte courant, act)`, jamais en arrière.
/// Un [act] hors de 1 à 3 est ignoré. La correction se fait par
/// [StageActAdvanced] (clic manuel) ou [StageResetRequested].
final class StageActReached extends StageEvent {
  const StageActReached(this.act);

  /// Acte atteint (1 à 3).
  final int act;
}
