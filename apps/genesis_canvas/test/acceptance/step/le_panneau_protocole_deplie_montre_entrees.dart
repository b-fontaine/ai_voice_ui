import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: le panneau protocole déplié montre {4} entrées
///
/// Le nombre d'entrées montrées est celui mesuré avant 018 : la correction de
/// la pose du panneau ne change ni sa hauteur ni son contenu.
Future<void> lePanneauProtocoleDeplieMontreEntrees(
  WidgetTester tester,
  num count,
) async {
  final entries = find.byWidgetPredicate(
    (w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('protocol-entry-'),
  );
  expect(
    entries.evaluate().length,
    count,
    reason: 'le panneau déplié doit montrer $count entrées',
  );
}
