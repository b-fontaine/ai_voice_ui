import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_canvas/main.dart';

void main() {
  testWidgets("l'app démarre et affiche l'orbe et le canevas vide", (
    tester,
  ) async {
    await tester.pumpWidget(const GenesisCanvasApp());

    expect(find.byKey(const Key('voice-orb')), findsOneWidget);
    expect(find.byKey(const Key('canvas-board')), findsOneWidget);
  });
}
