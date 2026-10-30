import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_until.dart';

/// Usage: la ligne {'ai'} de la transcription n'affiche pas {'la décision attend'}
Future<void> laLigneDeLaTranscriptionNaffichePas(
  WidgetTester tester,
  String role,
  String text,
) async {
  await settleReal(tester, duration: const Duration(milliseconds: 150));
  await tester.pump();
  expect(
    find.descendant(
      of: find.byKey(Key('transcript-$role')),
      matching: find.textContaining(text),
      matchRoot: true,
    ),
    findsNothing,
    reason:
        'transcript-$role affiche « $text » : la réplique n\'est pas tronquée',
  );
}
