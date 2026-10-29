import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_canvas/app/config/genesis_config.dart';
import 'package:genesis_canvas/app/app.dart';
import 'package:genui/genui.dart' show Surface;

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

const _replay =
    '''
{"t_ms": 0, "message": {"version":"v0.9","createSurface":{"surfaceId":"s","catalogId":"$_catalog"}}}
{"t_ms": 0, "message": {"version":"v0.9","updateComponents":{"surfaceId":"s","components":[{"id":"root","component":"Text","text":"Sessions sans crash"}]}}}
''';

void main() {
  testWidgets('le texte rendu dans la surface est lisible sur le fond sombre', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      GenesisCanvasApp(
        config: const GenesisConfig(scenario: 'demo'),
        exitHandler: (_) {},
        assetBundle: _FakeBundle(<String, String>{
          'assets/replays/demo.jsonl': _replay,
        }),
        replayDelay: (_) async {},
      ),
    );
    await tester.pump();
    await tester.pump();

    final text = find.descendant(
      of: find.byType(Surface),
      matching: find.text('Sessions sans crash'),
    );
    expect(text, findsOneWidget);

    // Style effectif : style explicite du Text fusionné avec le
    // DefaultTextStyle hérité du contexte.
    final context = tester.element(text);
    final widget = tester.widget<Text>(text);
    final effective = DefaultTextStyle.of(context).style.merge(widget.style);
    expect(effective.color, isNotNull);
    expect(effective.color!.computeLuminance(), greaterThan(0.5));
  });
}
