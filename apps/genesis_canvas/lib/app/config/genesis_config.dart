/// Configuration de lancement de l'app, lue une fois dans `main()` puis
/// injectée par constructeur jusqu'à la page.
class GenesisConfig {
  const GenesisConfig({this.scenario, this.snapshotPath});

  /// Construit la configuration à partir d'un environnement (en prod
  /// `Platform.environment`). Une variable absente ou vide vaut `null`.
  factory GenesisConfig.fromEnvironment(Map<String, String> environment) =>
      GenesisConfig(
        scenario: _read(environment, 'GENESIS_SCENARIO'),
        snapshotPath: _read(environment, 'GENESIS_SNAPSHOT'),
      );

  /// Nom du rejeu `assets/replays/<scenario>.jsonl` ; `null` : canevas vide.
  final String? scenario;

  /// Chemin du PNG à écrire à la fin du rejeu ; `null` : pas de capture.
  final String? snapshotPath;

  static String? _read(Map<String, String> environment, String name) {
    final value = environment[name]?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }
}
