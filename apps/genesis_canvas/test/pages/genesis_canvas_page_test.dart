import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_backend_channel/shared_backend_channel.dart'
    show CanvasResetClient, CanvasResetResult;

import '../support/page_settings.dart';

import 'package:genesis_canvas/app/bootstrap/snapshot_service.dart';
import 'package:genesis_canvas/app/config/genesis_config.dart';
import 'package:genesis_canvas/app/di/injection.dart';
import 'package:genesis_canvas/app/scenario/scenario_player.dart';
import 'package:genesis_canvas/pages/genesis_canvas/genesis_canvas.dart';
import 'package:entity_catalog/entity_catalog.dart' show GenesisContract;
import 'package:feature_canvas/feature_canvas.dart' show genesisCatalog;
import 'package:genui/genui.dart' show Catalog;
import 'package:shared_core/shared_core.dart' show ReplayedMessage;
import 'package:get_it/get_it.dart';

import '../support/replay_rig.dart';

/// Faux paquet d'assets : frontière plateforme, contenu par chemin.
class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this.assets);

  final Map<String, String> assets;

  @override
  Future<ByteData> load(String key) async {
    final text = assets[key];
    if (text == null) throw FlutterError('asset absent : $key');
    return ByteData.sublistView(Uint8List.fromList(text.codeUnits));
  }
}

class _DoneResetClient implements CanvasResetClient {
  @override
  Future<CanvasResetResult> reset() async => CanvasResetResult.done;
}

const _catalog = GenesisContract.defaultCatalogId;

// Composant hors catalogue fermé : le gate A2UI le refuse (le moteur ne le voit
// jamais) ; le code fermé est consigné, jamais le contenu.
const _unknownComponent =
    '''
{"t_ms": 0, "message": {"version":"v0.9","createSurface":{"surfaceId":"s","catalogId":"$_catalog"}}}
{"t_ms": 0, "message": {"version":"v0.9","updateComponents":{"surfaceId":"s","components":[{"id":"root","component":"Inconnu"}]}}}
''';

// Rejeu conforme au contrat. Avec un catalogue vide injecté, le gate l'accepte
// mais genui signale une erreur par `reportError`, sans lever d'exception.
const _valid =
    '''
{"t_ms": 0, "message": {"version":"v0.9","createSurface":{"surfaceId":"kpi","catalogId":"$_catalog"}}}
{"t_ms": 0, "message": {"version":"v0.9","updateComponents":{"surfaceId":"kpi","components":[{"id":"root","component":"KeyIndicator","data":{"path":"/kpi"}}]}}}
{"t_ms": 0, "message": {"version":"v0.9","updateDataModel":{"surfaceId":"kpi","path":"/kpi","value":{"label":"ok","value":"1","trend":"0","threshold":"1","status":"ok","statusLabel":"OK"}}}}
''';

void main() {
  late List<int> exitCodes;
  late StringBuffer errors;
  late Directory dir;

  /// Graphe réel de l'app (aucune E/S à la résolution), propre à chaque test.
  GetIt newGetIt() {
    final getIt = GetIt.asNewInstance();
    configureDependencies(
      getIt,
      config: const GenesisConfig(),
      errorSink: StringBuffer(),
    );
    // Frontière réseau : en mode vivant, la page demande la remise à vide du
    // backend au démarrage (pdr-0064, D6) ; le banc de test répondrait 400.
    getIt.unregister<CanvasResetClient>();
    getIt.registerSingleton<CanvasResetClient>(_DoneResetClient());
    addTearDown(getIt.reset);
    return getIt;
  }

  setUp(() {
    exitCodes = <int>[];
    errors = StringBuffer();
    dir = Directory.systemTemp.createTempSync('genesis_page_test');
    addTearDown(() => dir.deleteSync(recursive: true));
  });

  Future<void> launch(
    WidgetTester tester,
    String? jsonl, {
    bool capture = true,
    String scenario = 'demo',
    bool withReplay = true,
    List<Catalog>? catalogs,
  }) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ReplayScope(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: withOverlay(
            GenesisCanvasPage(
              getIt: newGetIt(),
              catalogs:
                  catalogs ?? <Catalog>[genesisCatalog(catalogId: _catalog)],
              replay: withReplay
                  ? ScenarioPlayer(
                      bundle: _FakeBundle(<String, String>{
                        'assets/replays/demo.jsonl': ?jsonl,
                      }),
                    ).entries(scenario)
                  : null,
              snapshotFactory: (exitHandler) => SnapshotService(
                path: capture ? '${dir.path}/out.png' : null,
                exitHandler: exitHandler,
                errorSink: errors,
              ),
              exitHandler: exitCodes.add,
              errorSink: errors,
              settings: pageSettingsOf(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 30),
    );
    // La capture PNG s'achève dans la boucle d'événements réelle.
    await tester.runAsync(() async {
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (exitCodes.isEmpty && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pump();
  }

  test('une seule source du catalogue : deux catalogues sont refusés', () {
    GenesisCanvasPage page(List<Catalog> catalogs) => GenesisCanvasPage(
      getIt: GetIt.asNewInstance(),
      catalogs: catalogs,
      snapshotFactory: (exitHandler) => SnapshotService(
        path: null,
        exitHandler: exitHandler,
        errorSink: errors,
      ),
      exitHandler: exitCodes.add,
      errorSink: errors,
      settings: pageSettingsOf(),
    );

    expect(
      () => page(<Catalog>[
        genesisCatalog(catalogId: _catalog),
        genesisCatalog(catalogId: '$_catalog-bis'),
      ]),
      throwsAssertionError,
    );
    expect(() => page(const <Catalog>[]), throwsAssertionError);
    expect(
      page(<Catalog>[genesisCatalog(catalogId: _catalog)]).catalogId,
      _catalog,
    );
  });

  testWidgets('erreur du moteur pendant le rejeu : message et sortie 1', (
    tester,
  ) async {
    await launch(
      tester,
      _valid,
      catalogs: <Catalog>[Catalog(const [], catalogId: _catalog)],
    );

    expect(exitCodes, <int>[1]);
    expect(errors.toString(), contains('Erreur du moteur genui'));
  });

  testWidgets('message refusé pendant le rejeu : code fermé seul et sortie 1', (
    tester,
  ) async {
    await launch(tester, _unknownComponent);

    expect(exitCodes, <int>[1]);
    expect(errors.toString(), contains('component_not_allowed'));
    expect(errors.toString(), isNot(contains('Inconnu')));
  });

  testWidgets('rejeu conforme : PNG écrit et sortie 0', (tester) async {
    await launch(tester, _valid);

    expect(exitCodes, <int>[0]);
    expect(errors.toString(), isEmpty);
  });

  testWidgets('scénario absent avec capture : message et sortie 1', (
    tester,
  ) async {
    await launch(tester, null);

    expect(exitCodes, <int>[1]);
    expect(errors.toString(), contains('impossible'));
  });

  testWidgets('scénario absent sans capture : message, aucune sortie', (
    tester,
  ) async {
    await launch(tester, null, capture: false);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();

    expect(exitCodes, isEmpty);
    expect(errors.toString(), contains('impossible'));
  });

  testWidgets('rejeu valide sans capture : aucune sortie', (tester) async {
    await launch(tester, _valid, capture: false);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();

    expect(exitCodes, isEmpty);
    expect(errors.toString(), isEmpty);
  });

  testWidgets('capture active sans scénario : PNG non vide et sortie 0', (
    tester,
  ) async {
    await launch(tester, null, withReplay: false);

    expect(exitCodes, <int>[0]);
    expect(errors.toString(), isEmpty);
    final png = File('${dir.path}/out.png');
    expect(png.existsSync(), isTrue);
    expect(png.lengthSync(), greaterThan(0));
  });

  testWidgets('page démontée avant la capture : message et sortie 1', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final messages = StreamController<ReplayedMessage>();
    await tester.pumpWidget(
      ReplayScope(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: withOverlay(
            GenesisCanvasPage(
              getIt: newGetIt(),
              catalogs: <Catalog>[genesisCatalog(catalogId: _catalog)],
              replay: messages.stream,
              snapshotFactory: (exitHandler) => SnapshotService(
                path: '${dir.path}/out.png',
                exitHandler: exitHandler,
                errorSink: errors,
              ),
              exitHandler: exitCodes.add,
              errorSink: errors,
              settings: pageSettingsOf(),
            ),
          ),
        ),
      ),
    );
    unawaited(messages.close());
    // Laisse le statut `completed` arriver, puis démonte avant la fin de
    // l'attente de stabilisation.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (exitCodes.isEmpty && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });

    expect(exitCodes, <int>[1]);
    expect(errors.toString(), contains('démontée'));
  });
}
