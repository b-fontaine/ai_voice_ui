/// Statut fermé d'un indicateur, repris des codes du contrat (`ok|risk|blocking`).
///
/// La couleur dépend de ce code et jamais d'un libellé français.
enum SceneStatus {
  ok,
  risk,
  blocking;

  /// Convertit un code du contrat ; `null` pour tout code inconnu ou absent.
  static SceneStatus? fromCode(String? code) {
    for (final status in values) {
      if (status.name == code) return status;
    }
    return null;
  }
}
