import 'dart:io';

import 'package:flutter/material.dart' show Key;
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart' show Surface;

import '../acceptance/support/session_harness.dart';
import '../support/pump_until.dart';

/// R2 : les rappels de diagnostic sont branchés sur le puits d'erreurs de
/// l'app (phrases fermées, jamais de contenu reçu).
void main() {
  List<String> lines(StringBuffer sink) =>
      sink.toString().split('\n').where((l) => l.isNotEmpty).toList();

  testWidgets('enveloppe invalide et a2ui refusé : une ligne chacun, '
      'l\'app reste vivante', (tester) async {
    final sink = StringBuffer();
    await SessionHarness.startBackend(tester);
    try {
      await SessionHarness.launchApp(tester, errorSink: sink);
      await SessionHarness.tap(tester, SessionHarness.startKey);
      await SessionHarness.waitForActiveSession(tester);
      final session = SessionHarness.backend.lastSessionId!;

      await SessionHarness.onServer(
        tester,
        () async =>
            SessionHarness.backend.emitRaw(session, 'pas du JSON secret'),
      );
      await SessionHarness.onServer(
        tester,
        () async => SessionHarness.backend.emit(
          session,
          'a2ui',
          <String, Object?>{'version': 'v0.9', 'inconnu': 1},
        ),
      );

      await pumpUntil(
        tester,
        () => lines(sink).length >= 2,
        timeout: SessionHarness.wait,
        reason: 'diagnostics absents : ${sink.toString()}',
      );
      expect(lines(sink), <String>[
        'Enveloppe ignorée : JSON invalide',
        'Message ignoré : message A2UI refusé',
      ]);
      expect(sink.toString(), isNot(contains('secret')));

      // Surface suivante rendue : l'app n'a pas été interrompue.
      await SessionHarness.emitFixture(
        tester,
        (e) => SessionHarness.isType(e, 'a2ui'),
      );
      await SessionHarness.waitFor(
        tester,
        find.byType(Surface),
        'surface suivante non rendue',
      );
      expect(lines(sink), hasLength(2));
    } finally {
      await SessionHarness.shutDown(tester);
    }
  });

  testWidgets('erreur d\'E/S du journal : une ligne sur le puits', (
    tester,
  ) async {
    final sink = StringBuffer();
    final dir = Directory.systemTemp.createTempSync('genesis_diag_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/ordinaire')..writeAsStringSync('x');
    await SessionHarness.startBackend(tester);
    try {
      await SessionHarness.launchApp(
        tester,
        appLogPath: '${file.path}/app.jsonl',
        errorSink: sink,
      );
      await SessionHarness.tap(tester, SessionHarness.startKey);
      await SessionHarness.waitForActiveSession(tester);

      await pumpUntil(
        tester,
        () => sink.isNotEmpty,
        timeout: SessionHarness.wait,
        reason: 'aucune ligne de diagnostic du journal',
      );
      expect(lines(sink), <String>[
        "Journal de l'app désactivé (erreur d'E/S).",
      ]);
      expect(find.byKey(const Key('stop-button')), findsOneWidget);
    } finally {
      await SessionHarness.shutDown(tester);
    }
  });
}
