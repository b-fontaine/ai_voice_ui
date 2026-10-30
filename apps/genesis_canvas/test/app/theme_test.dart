import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:entity_catalog/entity_catalog.dart' show GenesisContract;
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_canvas/app/config/genesis_config.dart';
import 'package:genesis_canvas/app/app.dart';
import 'package:genui/genui.dart' show Surface;

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

const _catalog = GenesisContract.defaultCatalogId;

const _replay =
    '''
{"t_ms": 0, "message": {"version":"v0.9","createSurface":{"surfaceId":"kpi","catalogId":"$_catalog"}}}
{"t_ms": 0, "message": {"version":"v0.9","updateComponents":{"surfaceId":"kpi","components":[{"id":"root","component":"KeyIndicator","data":{"path":"/kpi"}}]}}}
{"t_ms": 0, "message": {"version":"v0.9","updateDataModel":{"surfaceId":"kpi","path":"/kpi","value":{"label":"Sessions sans crash","value":"99,57 %","trend":"-0,36 pt","threshold":"99,50 %","status":"risk","statusLabel":"Risque"}}}}
''';

void main() {
  testWidgets('le texte rendu dans la surface est lisible sur le fond sombre', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ReplayScope(
        child: GenesisCanvasApp(
          config: const GenesisConfig(scenario: 'demo'),
          exitHandler: (_) {},
          assetBundle: _FakeBundle(<String, String>{
            'assets/replays/demo.jsonl': _replay,
          }),
          replayDelay: (_) async {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final text = find.descendant(
      of: find.byType(Surface),
      // La valeur (texte principal du KPI) ; le libellé est volontairement
      // en gris secondaire.
      matching: find.text('99,57 %'),
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
