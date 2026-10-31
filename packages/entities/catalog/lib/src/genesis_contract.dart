/// Contrat du catalogue `genesis` v1, côté client (Dart pur).
///
/// Source de vérité : `contracts/a2ui/genesis/v1/catalog.json` ; un test
/// vérifie l'égalité. T12 complète ce contrat et ajoute le validateur.
abstract final class GenesisContract {
  /// Identifiant de catalogue par défaut (pdr-0055, provisoire : Q-44).
  static const String defaultCatalogId =
      'https://genesis-canvas.example/a2ui/catalogs/genesis/v1';

  /// Les 6 composants que le client accepte dans `updateComponents` (dans
  /// l'ordre de `catalog.json`, qui est celui de `A2UI_COMPONENTS`).
  static const List<String> components = <String>[
    'KeyIndicator',
    'TrendChart',
    'ReviewSentiment',
    'ReleaseChecklist',
    'ActionBar',
    'CrashList',
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

  /// Champs obligatoires de l'objet lié, par composant. `comparison` (acte 2,
  /// `KeyIndicator` et `ReviewSentiment`) est facultatif : il n'apparaît pas
  /// ici, mais ses champs requis sont dans [requiredNestedFields].
  static const Map<String, List<String>> requiredFields =
      <String, List<String>>{
        'KeyIndicator': <String>[
          'label',
          'value',
          'trend',
          'threshold',
          'status',
          'statusLabel',
        ],
        'TrendChart': <String>[
          'title',
          'thresholdPct',
          'yMaxPct',
          'days',
          'series',
        ],
        'ReviewSentiment': <String>[
          'title',
          'count',
          'positivePct',
          'negativePct',
          'average',
          'excerpts',
        ],
        'ReleaseChecklist': <String>[
          'title',
          'items',
          'recommendation',
          'decisionStatus',
        ],
        'ActionBar': <String>['title', 'actions'],
        'CrashList': <String>['title', 'items'],
      };

  /// Champs obligatoires des éléments ou sous-objets, par composant puis par
  /// champ parent (`series` → `name`, `points`, etc.). `comparison` est
  /// facultatif ; quand il est présent, ses trois champs sont requis.
  static const Map<String, Map<String, List<String>>> requiredNestedFields =
      <String, Map<String, List<String>>>{
        'KeyIndicator': <String, List<String>>{
          'comparison': <String>['label', 'value', 'delta'],
        },
        'TrendChart': <String, List<String>>{
          'series': <String>['name', 'points'],
        },
        'ReviewSentiment': <String, List<String>>{
          'excerpts': <String>['stars', 'platform', 'text'],
          'comparison': <String>['label', 'value', 'delta'],
        },
        'ReleaseChecklist': <String, List<String>>{
          'items': <String>[
            'label',
            'threshold',
            'value',
            'level',
            'levelLabel',
          ],
          'recommendation': <String>['level', 'label'],
        },
        'ActionBar': <String, List<String>>{
          'actions': <String>['id', 'label', 'tone'],
        },
        'CrashList': <String, List<String>>{
          'items': <String>['rank', 'label', 'platform', 'volume', 'sessions'],
        },
      };

  /// Sous-chemins qu'un `updateDataModel` peut écrire en plus de l'objet entier
  /// de la surface : chemin complet -> type JSON attendu (R4, spec 009). Miroir
  /// des `writableSubPaths` de `catalog.json` (valeur de `A2UI_WRITABLE_SUBPATHS`).
  static const Map<String, String> writableSubPaths = <String, String>{
    '/checklist/decisionStatus': 'string',
  };

  /// Identifiants d'action admis (ensemble fermé, pdr-0065) : `id` des
  /// éléments de `actions` de la Barre d'actions.
  static const List<String> actionIds = <String>[
    'block_release',
    'validate_release',
  ];

  /// Tons admis d'un bouton de la Barre d'actions.
  static const List<String> actionTones = <String>['neutral', 'danger'];

  static const Map<String, String> _surfaceByComponent = <String, String>{
    'KeyIndicator': 'kpi',
    'TrendChart': 'trend',
    'ReviewSentiment': 'reviews',
    'ReleaseChecklist': 'checklist',
    'ActionBar': 'actions',
    'CrashList': 'crashes',
  };

  /// Surface propre à [component], ou `null` s'il n'est pas dans [components].
  static String? surfaceOf(String component) => _surfaceByComponent[component];

  /// Chemin du data model lié par `data: {path}`, ou `null` si inconnu.
  static String? boundPathOf(String component) {
    final String? surface = surfaceOf(component);
    return surface == null ? null : '/$surface';
  }
}
