import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

/// Bordure que Material peint autour du bouton [key] : le `ButtonStyle.side`
/// résolu, tel que le rend le `Material` du bouton.
BorderSide paintedSide(WidgetTester tester, Key key) {
  final Finder material = find
      .descendant(of: find.byKey(key), matching: find.byType(Material))
      .first;
  final ShapeBorder? shape = tester.widget<Material>(material).shape;
  return (shape! as OutlinedBorder).side;
}

/// Donne le focus clavier au bouton [key] (le nœud de focus de son `InkWell`,
/// ancêtre de [childKey]) et laisse l'arbre se reconstruire.
Future<void> focusButton(WidgetTester tester, Key key, Key childKey) async {
  expect(find.byKey(key), findsOneWidget);
  Focus.of(tester.element(find.byKey(childKey))).requestFocus();
  await tester.pump();
}

/// Vérifie l'anneau `signal` de 2 points au focus et son absence au repos.
Future<void> expectFocusRing(WidgetTester tester, Key key, Key childKey) async {
  const SceneTheme theme = SceneTheme.dark();
  expect(paintedSide(tester, key), BorderSide.none, reason: '$key au repos');
  await focusButton(tester, key, childKey);
  final BorderSide side = paintedSide(tester, key);
  expect(side.color, theme.accent, reason: '$key focus : couleur');
  expect(side.width, 2, reason: '$key focus : épaisseur');
}
