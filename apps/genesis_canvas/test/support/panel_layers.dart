import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

/// Vérifie qu'une zone de l'enveloppe dessine son fond avec la décoration de
/// panneau du design system (pdr-0084 U9) : une `ScenePanelDecoration` sœur du
/// contenu, sans `Clip` au-dessus (l'ombre ne doit pas être rognée), et plus de
/// `DecoratedBox` qui peigne `surface` avec un rayon littéral.
void expectPanelDecoration(WidgetTester tester, Finder zone) {
  final Finder decoration = find.descendant(
    of: zone,
    matching: find.byType(ScenePanelDecoration),
  );
  expect(decoration, findsOneWidget);
  // Le `Material` transparent des zones pose un `ClipPath` en `Clip.none` : il
  // ne rogne rien. On refuse tout `Clip` qui rogne vraiment.
  final Finder clipping = find.descendant(
    of: zone,
    matching: find.ancestor(
      of: decoration,
      matching: find.byWidgetPredicate(
        (Widget w) => switch (w) {
          ClipRect(:final Clip clipBehavior) ||
          ClipRRect(:final Clip clipBehavior) ||
          ClipPath(:final Clip clipBehavior) ||
          ClipOval(:final Clip clipBehavior) => clipBehavior != Clip.none,
          _ => false,
        },
      ),
    ),
  );
  expect(clipping, findsNothing, reason: 'aucun Clip rogneur au-dessus');
  const SceneTheme theme = SceneTheme.dark();
  final Iterable<DecoratedBox> filled = tester
      .widgetList<DecoratedBox>(
        find.descendant(of: zone, matching: find.byType(DecoratedBox)),
      )
      .where((DecoratedBox box) {
        final Decoration d = box.decoration;
        return d is BoxDecoration && d.color == theme.surface;
      });
  expect(filled, isEmpty, reason: 'plus de fond `surface` peint à la main');
}
