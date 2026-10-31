import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: je clique sur la commande {'mic-button'}
///
/// Clic sur la commande de la régie portant la clé [key] (`silence-button`,
/// `mic-button`). Une commande absente fait échouer le scénario tout de suite.
Future<void> jeCliqueSurLaCommande(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  expect(
    finder,
    findsOneWidget,
    reason: 'la commande « $key » est absente de la régie',
  );
  await tester.tap(finder, warnIfMissed: false);
  await tester.pump();
}
