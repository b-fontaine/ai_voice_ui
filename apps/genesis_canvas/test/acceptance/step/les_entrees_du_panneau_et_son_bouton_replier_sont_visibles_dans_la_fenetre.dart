import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/design_harness.dart';
import '../support/keys.dart';

/// Usage: les entrées du panneau et son bouton Replier sont visibles dans la fenêtre
Future<void> lesEntreesDuPanneauEtSonBoutonReplierSontVisiblesDansLaFenetre(
  WidgetTester tester,
) async {
  final window = DesignHarness.windowRect(tester);
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
  final entries = AcceptanceKeys.protocolEntries();
  expect(
    entries,
    findsWidgets,
    reason: 'le panneau déplié ne montre aucune entrée',
  );
  for (var i = 0; i < entries.evaluate().length; i++) {
    final entry = entries.at(i);
    final rect = tester.getRect(entry);
    expect(
      inside(rect),
      isTrue,
      reason:
          'l\'entrée ${entry.evaluate().single.widget.key} ($rect) sort de la fenêtre ($window)',
    );
  }
}
