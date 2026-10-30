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
