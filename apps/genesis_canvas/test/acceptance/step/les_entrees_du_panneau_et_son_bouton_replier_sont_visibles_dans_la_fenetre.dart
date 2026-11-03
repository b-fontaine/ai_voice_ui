import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/keys.dart';

/// Usage: les entrées du panneau et son bouton Replier sont visibles dans la fenêtre
Future<void> lesEntreesDuPanneauEtSonBoutonReplierSontVisiblesDansLaFenetre(
  WidgetTester tester,
) async {
  final window =
      Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio);
  bool inside(Rect r) =>
      r.left >= window.left - 0.5 &&
      r.top >= window.top - 0.5 &&
      r.right <= window.right + 0.5 &&
      r.bottom <= window.bottom + 0.5;

  final replier = find.descendant(
    of: find.byKey(AcceptanceKeys.protocolToggle),
    matching: find.text('Replier'),
  );
  expect(replier, findsOneWidget, reason: 'le bouton « Replier » est absent');
  expect(
    inside(tester.getRect(replier)),
    isTrue,
    reason: 'le bouton « Replier » sort de la fenêtre ($window)',
  );
  final entries = find.byWidgetPredicate(
    (w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('protocol-entry-'),
  );
  expect(
    entries,
    findsWidgets,
    reason: 'le panneau déplié ne montre aucune entrée',
  );
  for (final element in entries.evaluate()) {
    final rect = tester.getRect(find.byElementPredicate((e) => e == element));
    expect(
      inside(rect),
      isTrue,
      reason:
          'l\'entrée ${element.widget.key} ($rect) sort de la fenêtre ($window)',
    );
  }
}
