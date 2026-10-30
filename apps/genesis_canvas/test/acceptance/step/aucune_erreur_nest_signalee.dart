import 'package:flutter_test/flutter_test.dart';

/// Usage: aucune erreur n'est signalée
Future<void> aucuneErreurNestSignalee(WidgetTester tester) async {
  expect(
    tester.takeException(),
    isNull,
    reason:
        "le moteur ou un widget a signalé une erreur (l'état neutre n'en "
        'lève jamais, RG-10)',
  );
}
