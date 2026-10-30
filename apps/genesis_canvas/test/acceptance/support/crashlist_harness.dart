import 'package:flutter_test/flutter_test.dart';
import 'package:testing_backend_fakes/testing_backend_fakes.dart';

import 'session_harness.dart';

/// Messages A2UI de la surface `crashes` (composant `CrashList`, spec 012) et
/// leur émission par le faux backend.
///
/// Les exemples `crashlist-*` du contrat arrivent avec T11 : en attendant, le
/// test définit lui-même les trois messages, au format de `act2-actions`
/// (`createSurface`, `updateComponents`, `updateDataModel`). Les cinq lignes
/// sont celles de `product/functional/dataset.md` (« Liste des crashs »).
class CrashListHarness {
  CrashListHarness._();

  static const String surfaceId = 'crashes';
  static const String agent = 'Qualité';
  static const String task = 'task_crashes';
  static const String title = 'Principaux crashs · 3.4';

  /// Top 5 des crashs de la 3.4 (rang, libellé, plateforme, volume, sessions).
  static List<Map<String, Object?>> items() => <Map<String, Object?>>[
    _row(
      1,
      'Plantage à la validation du panier (3-D Secure 2)',
      'Android',
      371,
      352,
    ),
    _row(
      2,
      "Fermeture au retour de l'app bancaire (WebView 3-D Secure)",
      'Android',
      148,
      139,
    ),
    _row(
      3,
      "Mémoire saturée à l'ouverture de la galerie photos",
      'Android',
      72,
      66,
    ),
    _row(
      4,
      'Crash au démarrage à froid (migration de la base locale 3.4)',
      'iOS',
      58,
      55,
    ),
    _row(5, "Plantage à l'ouverture d'une notification push", 'iOS', 41, 39),
  ];

  static Map<String, Object?> _row(
    int rank,
    String label,
    String platform,
    int volume,
    int sessions,
  ) => <String, Object?>{
    'rank': rank,
    'label': label,
    'platform': platform,
    'volume': volume,
    'sessions': sessions,
  };

  /// Faux backend (un par scénario) pour lequel des temps ont déjà été émis,
  /// et leur nombre : un temps n'est jamais renvoyé deux fois dans le même
  /// scénario. L'identifiant de session ne distingue pas les scénarios (il est
  /// réutilisé d'un faux backend à l'autre).
  static Object? _emittedFor;
  static int _emitted = 0;

  /// Les trois messages, [catalogId] substitué ; [value] remplace le modèle de
  /// données (cas hors contrat, état neutre).
  static List<Map<String, Object?>> messages(
    String catalogId, {
    Object? value,
  }) => <Map<String, Object?>>[
    <String, Object?>{
      'version': 'v0.9',
      'createSurface': <String, Object?>{
        'surfaceId': surfaceId,
        'catalogId': catalogId,
        'sendDataModel': false,
      },
    },
    <String, Object?>{
      'version': 'v0.9',
      'updateComponents': <String, Object?>{
        'surfaceId': surfaceId,
        'components': <Object?>[
          <String, Object?>{
            'id': 'root',
            'component': 'CrashList',
            'data': <String, Object?>{'path': '/crashes'},
          },
        ],
      },
    },
    <String, Object?>{
      'version': 'v0.9',
      'updateDataModel': <String, Object?>{
        'surfaceId': surfaceId,
        'path': '/crashes',
        'value': value ?? <String, Object?>{'title': title, 'items': items()},
      },
    },
  ];

  /// Émet les temps de [SurfaceStage.skeleton] à [upTo] qui ne l'ont pas
  /// encore été dans la session courante.
  static Future<void> emitUpTo(
    WidgetTester tester,
    SurfaceStage upTo, {
    Object? value,
  }) async {
    final backend = SessionHarness.backend;
    final session = backend.lastSessionId!;
    if (!identical(_emittedFor, backend)) {
      _emittedFor = backend;
      _emitted = 0;
    }
    final all = messages(backend.catalogId, value: value);
    final from = _emitted;
    _emitted = upTo.index + 1;
    await SessionHarness.onServer(tester, () async {
      for (var i = from; i <= upTo.index; i++) {
        backend.emit(
          session,
          'a2ui',
          all[i],
          tMs: 4000 + i * 50,
          agent: agent,
          task: task,
        );
      }
    });
  }
}
