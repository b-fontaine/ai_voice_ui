import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: la ligne {'ai'} de la transcription affiche {'analyse de la release'}
Future<void> laLigneDeLaTranscriptionAffiche(
  WidgetTester tester,
  String role,
  String text,
) async {
  final line = find.descendant(
    of: find.byKey(Key('transcript-$role')),
    matching: find.textContaining(text),
    matchRoot: true,
  );
  await SessionHarness.waitFor(
    tester,
    line,
    'transcript-$role doit afficher « $text »',
  );
}
