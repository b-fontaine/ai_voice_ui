const String testCatalogId =
    'https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json';

/// Messages A2UI v0.9 minimaux (forme JSON, comme dans un journal de rejeu).
Map<String, dynamic> createSurface(String id) => <String, dynamic>{
  'version': 'v0.9',
  'createSurface': <String, dynamic>{
    'surfaceId': id,
    'catalogId': testCatalogId,
  },
};

Map<String, dynamic> updateComponents(String id, String text) =>
    <String, dynamic>{
      'version': 'v0.9',
      'updateComponents': <String, dynamic>{
        'surfaceId': id,
        'components': <Map<String, dynamic>>[
          <String, dynamic>{'id': 'root', 'component': 'Text', 'text': text},
        ],
      },
    };

/// Composant dont le texte est lié au modèle de données.
Map<String, dynamic> updateBoundComponents(String id, String path) =>
    <String, dynamic>{
      'version': 'v0.9',
      'updateComponents': <String, dynamic>{
        'surfaceId': id,
        'components': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'root',
            'component': 'Text',
            'text': <String, dynamic>{'path': path},
          },
        ],
      },
    };

Map<String, dynamic> updateDataModel(String id, String path, Object value) =>
    <String, dynamic>{
      'version': 'v0.9',
      'updateDataModel': <String, dynamic>{
        'surfaceId': id,
        'path': path,
        'value': value,
      },
    };

Map<String, dynamic> deleteSurface(String id) => <String, dynamic>{
  'version': 'v0.9',
  'deleteSurface': <String, dynamic>{'surfaceId': id},
};
