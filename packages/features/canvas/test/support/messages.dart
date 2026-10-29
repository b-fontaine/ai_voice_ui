import 'package:a2ui_core/a2ui_core.dart' show A2uiMessage;

const String testCatalogId =
    'https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json';

/// Messages A2UI v0.9 minimaux, décodés depuis leur forme JSON.
A2uiMessage createSurface(String id) => A2uiMessage.fromJson(<String, dynamic>{
  'version': 'v0.9',
  'createSurface': <String, dynamic>{
    'surfaceId': id,
    'catalogId': testCatalogId,
  },
});

A2uiMessage updateComponents(String id, String text) =>
    A2uiMessage.fromJson(<String, dynamic>{
      'version': 'v0.9',
      'updateComponents': <String, dynamic>{
        'surfaceId': id,
        'components': <Map<String, dynamic>>[
          <String, dynamic>{'id': 'root', 'component': 'Text', 'text': text},
        ],
      },
    });

/// Composant dont le texte est lié au modèle de données.
A2uiMessage updateBoundComponents(String id, String path) =>
    A2uiMessage.fromJson(<String, dynamic>{
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
    });

A2uiMessage updateDataModel(String id, String path, Object value) =>
    A2uiMessage.fromJson(<String, dynamic>{
      'version': 'v0.9',
      'updateDataModel': <String, dynamic>{
        'surfaceId': id,
        'path': path,
        'value': value,
      },
    });

A2uiMessage deleteSurface(String id) => A2uiMessage.fromJson(<String, dynamic>{
  'version': 'v0.9',
  'deleteSurface': <String, dynamic>{'surfaceId': id},
});
