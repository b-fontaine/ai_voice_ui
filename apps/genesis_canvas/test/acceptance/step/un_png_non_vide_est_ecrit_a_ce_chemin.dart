import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

/// Usage: un PNG non vide est écrit à ce chemin
Future<void> unPngNonVideEstEcritACeChemin(WidgetTester tester) async {
  final file = Harness.snapshotFile!;
  // `RepaintBoundary.toImage` s'achève dans la boucle d'événements réelle,
  // que `pumpAndSettle` ne laisse pas tourner : on lui laisse du temps réel.
  await tester.runAsync(() async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!file.existsSync() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  });
  await tester.pump();
  expect(file.existsSync(), isTrue, reason: 'PNG absent : ${file.path}');
  final bytes = file.readAsBytesSync();
  expect(bytes, isNotEmpty);
  // Signature PNG.
  expect(bytes.sublist(0, 8), <int>[137, 80, 78, 71, 13, 10, 26, 10]);
}
