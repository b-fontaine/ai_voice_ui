import 'package:a2ui_core/a2ui_core.dart' show AgentToRendererMessage;

const String testCatalogId =
    'https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json';

/// Messages A2UI v0.9 minimaux, décodés depuis leur forme JSON.
AgentToRendererMessage createSurface(String id) =>
    AgentToRendererMessage.fromJson(<String, dynamic>{
      'version': 'v0.9',
      'createSurface': <String, dynamic>{
        'surfaceId': id,
        'catalogId': testCatalogId,
      },
    });

AgentToRendererMessage updateComponents(String id, String text) =>
    AgentToRendererMessage.fromJson(<String, dynamic>{
      'version': 'v0.9',
      'updateComponents': <String, dynamic>{
        'surfaceId': id,
        'components': <Map<String, dynamic>>[
          <String, dynamic>{'id': 'root', 'component': 'Text', 'text': text},
        ],
      },
    });

/// Composant dont le texte est lié au modèle de données.
AgentToRendererMessage updateBoundComponents(String id, String path) =>
    AgentToRendererMessage.fromJson(<String, dynamic>{
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

AgentToRendererMessage updateDataModel(String id, String path, Object value) =>
    AgentToRendererMessage.fromJson(<String, dynamic>{
      'version': 'v0.9',
      'updateDataModel': <String, dynamic>{
        'surfaceId': id,
        'path': path,
        'value': value,
      },
    });

AgentToRendererMessage deleteSurface(String id) =>
    AgentToRendererMessage.fromJson(<String, dynamic>{
      'version': 'v0.9',
      'deleteSurface': <String, dynamic>{'surfaceId': id},
    });
