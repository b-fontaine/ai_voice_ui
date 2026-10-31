import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: le panneau protocole est déplié
///
/// Déplié, le panneau montre ses dernières entrées (`protocol-entry-<n>`, `n`
/// = rang du Bloc) : après un long flux, la première (`protocol-entry-0`) n'en
/// fait plus partie, d'où la recherche d'une entrée quelconque.
Future<void> lePanneauProtocoleEstDeplie(WidgetTester tester) async {
  await SessionHarness.waitFor(
    tester,
    find.byWidgetPredicate((widget) {
      final key = widget.key;
      return key is ValueKey<String> && key.value.startsWith('protocol-entry-');
    }),
    'déplié, le panneau doit afficher ses entrées (protocol-entry-<n>)',
  );
}
