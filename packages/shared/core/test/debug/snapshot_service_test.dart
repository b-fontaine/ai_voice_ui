import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';

const _pngSignature = <int>[137, 80, 78, 71, 13, 10, 26, 10];

void main() {
  group('SnapshotService', () {
    final boundaryKey = GlobalKey();
    late Directory dir;
    late List<int> exitCodes;
    late StringBuffer errors;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('snapshot_service_');
      exitCodes = <int>[];
      errors = StringBuffer();
    });

    tearDown(() => dir.deleteSync(recursive: true));

    SnapshotService build({String? path, bool debugMode = true}) =>
        SnapshotService(
          path: path,
          exitHandler: exitCodes.add,
          errorSink: errors,
          debugMode: debugMode,
        );

    Future<void> pumpBoundary(WidgetTester tester) => tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: boundaryKey,
          child: const ColoredBox(
            color: Color(0xFF336699),
            child: SizedBox(width: 64, height: 32),
          ),
        ),
      ),
    );

    testWidgets('écrit un PNG non vide puis sort avec le code 0', (
      tester,
    ) async {
      await pumpBoundary(tester);
      final file = File('${dir.path}/sous/dossier/capture.png');

      await tester.runAsync(
        () => build(path: file.path).captureAndExit(boundaryKey),
      );

      expect(file.existsSync(), isTrue);
      final bytes = file.readAsBytesSync();
      expect(bytes.sublist(0, 8), _pngSignature);
      expect(bytes.length, greaterThan(8));
      expect(exitCodes, <int>[0]);
      expect(errors.toString(), isEmpty);
    });

    testWidgets('chemin inscriptible : message sur stderr et sortie 1', (
      tester,
    ) async {
      await pumpBoundary(tester);

      // Le chemin désigne un dossier existant : l'écriture échoue.
      await tester.runAsync(
        () => build(path: dir.path).captureAndExit(boundaryKey),
      );

      expect(exitCodes, <int>[1]);
      expect(errors.toString(), contains('capture'));
    });

    testWidgets('aucune frontière de rendu : sortie 1', (tester) async {
      await tester.pumpWidget(const SizedBox());
      final file = File('${dir.path}/capture.png');

      await tester.runAsync(
        () => build(path: file.path).captureAndExit(boundaryKey),
      );

      expect(exitCodes, <int>[1]);
      expect(file.existsSync(), isFalse);
      expect(errors.toString(), isNotEmpty);
    });

    testWidgets('inactif hors debug : ni fichier ni sortie', (tester) async {
      await pumpBoundary(tester);
      final file = File('${dir.path}/capture.png');
      final service = build(path: file.path, debugMode: false);

      await tester.runAsync(() => service.captureAndExit(boundaryKey));

      expect(service.isActive, isFalse);
      expect(file.existsSync(), isFalse);
      expect(exitCodes, isEmpty);
    });

    testWidgets('inactif sans chemin : ni fichier ni sortie', (tester) async {
      await pumpBoundary(tester);
      final service = build();

      await tester.runAsync(() => service.captureAndExit(boundaryKey));

      expect(service.isActive, isFalse);
      expect(exitCodes, isEmpty);
      expect(dir.listSync(), isEmpty);
    });
  });
}
