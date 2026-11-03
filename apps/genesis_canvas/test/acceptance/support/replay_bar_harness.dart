import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'acte4_harness.dart';
import 'keys.dart';

/// Mesures de la spec 018 : la barre de rejeu reste atteignable, panneau du
/// protocole replié ou déplié. Aucune constante de production n'est importée.
abstract final class ReplayBarHarness {
  /// Vitesses proposées par la barre (pdr-0066).
  static const List<num> speeds = <num>[0.25, 0.5, 1, 1.5, 2];

  /// Clés des commandes de la barre de rejeu.
  static List<Key> get controls => <Key>[
    ReplayKeys.play,
    ReplayKeys.restart,
    ReplayKeys.slider,
    ReplayKeys.direct,
    for (final speed in speeds) ReplayKeys.speed(speed),
  ];

  static Rect panelRect(WidgetTester tester) {
    final finder = find.byKey(AcceptanceKeys.protocolPanel);
    expect(finder, findsOneWidget, reason: 'protocol-panel introuvable');
    return tester.getRect(finder);
  }

  /// Une commande est atteignable quand le clic l'atteint et que son
  /// rectangle ne recoupe pas celui du panneau.
  static void expectReachable(WidgetTester tester, Key key) {
    final finder = find.byKey(key);
    expect(finder, findsOneWidget, reason: 'la commande $key est introuvable');
    expect(
      finder.hitTestable(),
      findsOneWidget,
      reason: 'la commande $key est recouverte',
    );
    final Rect control = tester.getRect(finder);
    final Rect panel = panelRect(tester);
    expect(
      control.overlaps(panel),
      isFalse,
      reason:
          'la commande $key est recouverte : son rectangle ($control) recoupe le panneau ($panel)',
    );
  }

  /// Le clic en [point] atteint le widget [key] (son objet de rendu figure
  /// dans le chemin de test d'atteinte).
  static void expectHit(WidgetTester tester, Key key, Offset point) {
    final element = find.byKey(key).evaluate().single;
    final result = tester.hitTestOnBinding(point);
    expect(
      result.path.any((entry) => entry.target == element.renderObject),
      isTrue,
      reason: 'le point $point de la commande $key est recouvert',
    );
  }
}
