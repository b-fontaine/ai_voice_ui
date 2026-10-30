import 'package:entity_catalog/entity_catalog.dart' show GenesisContract;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_canvas/app/app.dart';
import 'package:genesis_canvas/app/config/genesis_config.dart';
import 'package:shared_core/shared_core.dart' show AppClock;

/// Taille de l'écran de la démo (six zones, budget de la spec 007).
void _demoScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Au démarrage en mode vivant, la page demande la remise à vide du backend
/// (pdr-0064, D6). Sous le banc de test, toute requête HTTP reçoit un 400 : on
/// laisse la réponse arriver (horloge réelle), puis on avance l'horloge du
/// test au-delà du délai de la requête pour qu'aucun minuteur du client ne
/// survive au test.
Future<void> _settleStartupReset(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump(const GenesisConfig().canvasResetTimeout * 2);
}

/// Faux paquet d'assets : frontière plateforme.
class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this.text);

  final String text;

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(Uint8List.fromList(text.codeUnits));
}

/// Horloge fausse (frontière « temps ») qui compte ses lectures.
class _CountingClock implements AppClock {
  int reads = 0;

  @override
  int nowUnixMs() => 1761800000000 + (++reads) * 1000;
}

void main() {
  testWidgets(
    "l'horloge fournie remplace celle de l'app (panneau du protocole)",
    (tester) async {
      _demoScreen(tester);
      final clock = _CountingClock();
      const catalog = GenesisContract.defaultCatalogId;
      await tester.pumpWidget(
        GenesisCanvasApp(
          config: const GenesisConfig(scenario: 'demo'),
          errorSink: StringBuffer(),
          exitHandler: (_) {},
          clock: clock,
          replayDelay: (_) async {},
          assetBundle: _FakeBundle(
            '{"t_ms": 0, "message": {"version":"v0.9","createSurface":'
            '{"surfaceId":"kpi","catalogId":"$catalog"}}}\n',
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(clock.reads, greaterThan(0));
    },
  );

  testWidgets("l'app démarre et affiche l'orbe et le canevas vide", (
    tester,
  ) async {
    _demoScreen(tester);
    await tester.pumpWidget(GenesisCanvasApp(errorSink: StringBuffer()));
    await _settleStartupReset(tester);

    expect(find.byKey(const Key('voice-orb')), findsOneWidget);
    expect(find.byKey(const Key('canvas-board')), findsOneWidget);
  });

  testWidgets('chaque montage a son propre graphe : remontage sans état '
      'résiduel, même avec une autre configuration', (tester) async {
    _demoScreen(tester);
    await tester.pumpWidget(
      GenesisCanvasApp(
        errorSink: StringBuffer(),
        config: GenesisConfig(backendUrl: Uri.parse('http://127.0.0.1:1')),
      ),
    );
    await _settleStartupReset(tester);
    expect(find.byKey(const Key('start-button')), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    await tester.pumpWidget(
      GenesisCanvasApp(
        errorSink: StringBuffer(),
        config: GenesisConfig(backendUrl: Uri.parse('http://127.0.0.1:2')),
      ),
    );
    await _settleStartupReset(tester);
    expect(find.byKey(const Key('start-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
