/// Contrat du catalogue `genesis` v1, côté client (Dart pur).
///
/// Source de vérité : `contracts/a2ui/genesis/v1/catalog.json` ; un test
/// vérifie l'égalité. T12 complète ce contrat et ajoute le validateur.
abstract final class GenesisContract {
  /// Identifiant de catalogue par défaut (pdr-0055, provisoire : Q-44).
  static const String defaultCatalogId =
      'https://genesis-canvas.example/a2ui/catalogs/genesis/v1';

  /// Les 4 composants que le client accepte dans `updateComponents`.
  static const List<String> components = <String>[
    'KeyIndicator',
    'TrendChart',
    'ReviewSentiment',
    'ReleaseChecklist',
  ];

  /// Les 6 composants du catalogue de pdr-0014 (base de l'étagère).
  static const List<String> catalogComponents = <String>[
    'KeyIndicator',
    'TrendChart',
    'ReviewSentiment',
    'ReleaseChecklist',
    'ActionBar',
    'CrashList',
  ];

  /// Propriétés admises sur un composant.
  static const List<String> allowedProperties = <String>[
    'id',
    'component',
    'data',
  ];

  static const Map<String, String> _surfaceByComponent = <String, String>{
    'KeyIndicator': 'kpi',
    'TrendChart': 'trend',
    'ReviewSentiment': 'reviews',
    'ReleaseChecklist': 'checklist',
  };

  /// Surface propre à [component], ou `null` s'il n'est pas dans [components].
  static String? surfaceOf(String component) => _surfaceByComponent[component];

  /// Chemin du data model lié par `data: {path}`, ou `null` si inconnu.
  static String? boundPathOf(String component) {
    final String? surface = surfaceOf(component);
    return surface == null ? null : '/$surface';
  }
}
