/// Port vers la scène (canevas, panneau du protocole, étagère), implémenté par
/// la page de composition.
abstract interface class ReplayStage {
  /// Vide canevas, panneau et étagère, sans appel au backend ni remise à zéro
  /// de l'acte. Synchrone : les messages réinjectés arrivent ensuite.
  void clear();

  /// Remise à vide complète de la scène (sortie du rejeu).
  void exit();
}
