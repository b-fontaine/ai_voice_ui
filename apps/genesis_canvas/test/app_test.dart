import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_canvas/app/app.dart';
import 'package:genesis_canvas/app/config/genesis_config.dart';

/// Taille de l'écran de la démo (six zones, budget de la spec 007).
void _demoScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets("l'app démarre et affiche l'orbe et le canevas vide", (
    tester,
  ) async {
    _demoScreen(tester);
    await tester.pumpWidget(const GenesisCanvasApp());

    expect(find.byKey(const Key('voice-orb')), findsOneWidget);
    expect(find.byKey(const Key('canvas-board')), findsOneWidget);
  });

  testWidgets('chaque montage a son propre graphe : remontage sans état '
      'résiduel, même avec une autre configuration', (tester) async {
    _demoScreen(tester);
    await tester.pumpWidget(
      GenesisCanvasApp(
        config: GenesisConfig(backendUrl: Uri.parse('http://127.0.0.1:1')),
      ),
    );
    expect(find.byKey(const Key('start-button')), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    await tester.pumpWidget(
      GenesisCanvasApp(
        config: GenesisConfig(backendUrl: Uri.parse('http://127.0.0.1:2')),
      ),
    );
    expect(find.byKey(const Key('start-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
