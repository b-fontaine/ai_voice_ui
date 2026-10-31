import 'package:flutter_test/flutter_test.dart';
import 'package:testing_backend_fakes/testing_backend_fakes.dart';

import 'session_harness.dart';

/// Messages A2UI de la surface `crashes` (composant `CrashList`, spec 012) et
/// leur émission par le faux backend.
///
/// Le chemin nominal rejoue les trois messages de
/// `contracts/a2ui/genesis/v1/examples/crashlist-global.jsonl` (via
/// [ContractFixtures]) : une dérive du contrat fait échouer les scénarios.
/// Seuls les cas neutres (hors contrat) fournissent leur propre `value`.
class CrashListHarness {
  CrashListHarness._();

  static const String surfaceId = 'crashes';
  static const String agent = 'Qualité';
  static const String task = 'task_crashes';

  /// Modèle de données (`/crashes`) de l'exemple du contrat, copie modifiable.
  static Future<Map<String, Object?>> contractValue(WidgetTester tester) async {
    final messages = (await tester.runAsync(
      ContractFixtures.crashlistMessages,
    ))!;
    final data = messages.last['updateDataModel']! as Map<String, Object?>;
    final value = data['value']! as Map<String, Object?>;
    return <String, Object?>{
      'title': value['title'],
      'items': <Object?>[
        for (final row in value['items']! as List<Object?>)
          Map<String, Object?>.of(row! as Map<String, Object?>),
      ],
    };
  }

  /// Faux backend (un par scénario) pour lequel des temps ont déjà été émis,
  /// et leur nombre : un temps n'est jamais renvoyé deux fois dans le même
  /// scénario. L'identifiant de session ne distingue pas les scénarios (il est
  /// réutilisé d'un faux backend à l'autre).
  static Object? _emittedFor;
  static int _emitted = 0;

  /// Les trois messages du contrat (lus hors `FakeAsync`), [catalogId] substitué ; [value] remplace
  /// le modèle de données (cas hors contrat, état neutre).
  static Future<List<Map<String, Object?>>> messages(
    WidgetTester tester,
    String catalogId, {
    Object? value,
  }) async {
    final all = (await tester.runAsync(
      () => ContractFixtures.crashlistMessages(catalogId: catalogId),
    ))!;
    if (value == null) return all;
    final data = all.last['updateDataModel']! as Map<String, Object?>;
    return <Map<String, Object?>>[
      ...all.take(2),
      <String, Object?>{
        ...all.last,
        'updateDataModel': <String, Object?>{...data, 'value': value},
      },
    ];
  }

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
    final all = await messages(tester, backend.catalogId, value: value);
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
