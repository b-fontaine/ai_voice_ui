import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

/// Usage: l'app lancée avec GENESIS_SNAPSHOT vers un fichier temporaire et GENESIS_REPLAY_AT {0.5}
///
/// Scénario `act1-replay` : l'app entre en rejeu, se place à [fraction] du
/// journal et se met en pause avant d'écrire la capture (A3).
Future<void>
lappLanceeAvecGenesisSnapshotVersUnFichierTemporaireEtGenesisReplayAt(
  WidgetTester tester,
  num fraction,
) async {
  final dir = Directory.systemTemp.createTempSync('genesis_snapshot_');
  addTearDown(() => dir.deleteSync(recursive: true));
  final file = File('${dir.path}/capture.png');
  await Harness.launch(
    tester,
    environment: <String, String>{
      'GENESIS_SCENARIO': 'act1-replay',
      'GENESIS_SNAPSHOT': file.path,
      'GENESIS_REPLAY_AT': '$fraction',
    },
  );
  Harness.snapshotFile = file;
}
