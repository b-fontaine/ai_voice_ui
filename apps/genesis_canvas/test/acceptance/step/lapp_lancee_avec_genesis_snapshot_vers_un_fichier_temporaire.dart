import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

/// Usage: l'app lancée avec GENESIS_SNAPSHOT vers un fichier temporaire
Future<void> lappLanceeAvecGenesisSnapshotVersUnFichierTemporaire(
  WidgetTester tester,
) async {
  final dir = Directory.systemTemp.createTempSync('genesis_snapshot_');
  addTearDown(() => dir.deleteSync(recursive: true));
  final file = File('${dir.path}/capture.png');
  await Harness.launch(
    tester,
    scenario: 'act1-replay',
    snapshotPath: file.path,
  );
  Harness.snapshotFile = file;
}
