import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_canvas/app/scenario/scenario_player.dart';
import 'package:genesis_canvas/pages/genesis_canvas/genesis_canvas.dart';
import 'package:genui/genui.dart' show BasicCatalogItems, Catalog;
import 'package:shared_core/shared_core.dart' show SnapshotService;

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

const _catalog =
    'https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json';

// Composant hors catalogue : genui le signale par `reportError`
// (« Unknown component type »), sans lever d'exception.
const _unknownComponent =
    '''
{"t_ms": 0, "message": {"version":"v0.9","createSurface":{"surfaceId":"s","catalogId":"$_catalog"}}}
{"t_ms": 0, "message": {"version":"v0.9","updateComponents":{"surfaceId":"s","components":[{"id":"root","component":"Inconnu"}]}}}
''';

const _valid =
    '''
{"t_ms": 0, "message": {"version":"v0.9","createSurface":{"surfaceId":"s","catalogId":"$_catalog"}}}
{"t_ms": 0, "message": {"version":"v0.9","updateComponents":{"surfaceId":"s","components":[{"id":"root","component":"Text","text":"ok"}]}}}
''';

void main() {
  late List<int> exitCodes;
  late StringBuffer errors;
  late Directory dir;

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
  }) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: GenesisCanvasPage(
          catalogs: <Catalog>[BasicCatalogItems.asCatalog()],
          replay: ScenarioPlayer(
            bundle: _FakeBundle(<String, String>{
              'assets/replays/demo.jsonl': ?jsonl,
            }),
          ).messages(scenario),
          snapshotFactory: (exitHandler) => SnapshotService(
            path: capture ? '${dir.path}/out.png' : null,
            exitHandler: exitHandler,
            errorSink: errors,
          ),
          exitHandler: exitCodes.add,
          errorSink: errors,
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

  testWidgets('erreur du moteur pendant le rejeu : message et sortie 1', (
    tester,
  ) async {
    await launch(tester, _unknownComponent);

    expect(exitCodes, <int>[1]);
    expect(errors.toString(), contains('Unknown component type: Inconnu'));
  });

  testWidgets('rejeu sans erreur : PNG écrit et sortie 0', (tester) async {
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
}
