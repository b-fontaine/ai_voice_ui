import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_canvas/app/config/genesis_config.dart';
import 'package:genesis_canvas/pages/genesis_canvas/genesis_canvas.dart';

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

  Future<void> launch(WidgetTester tester, String jsonl) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: GenesisCanvasPage(
          config: GenesisConfig(
            scenario: 'demo',
            snapshotPath: '${dir.path}/out.png',
          ),
          assetBundle: _FakeBundle(<String, String>{
            'assets/replays/demo.jsonl': jsonl,
          }),
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
}
