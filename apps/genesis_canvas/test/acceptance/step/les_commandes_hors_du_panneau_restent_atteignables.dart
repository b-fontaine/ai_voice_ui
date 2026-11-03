import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/keys.dart';

/// Usage: les commandes hors du panneau restent atteignables
///
/// Les clics hors du rectangle du panneau le traversent : la surface `kpi`, les
/// boutons de la barre du haut et un bouton d'action de gauche reçoivent le clic.
Future<void> lesCommandesHorsDuPanneauRestentAtteignables(
  WidgetTester tester,
) async {
  final keys = <Key>[
    AcceptanceKeys.surface('kpi'),
    AcceptanceKeys.resetButton,
    const Key('mic-button'),
    AcceptanceKeys.actionButton('block_release'),
  ];
  for (final key in keys) {
    final finder = find.byKey(key);
    expect(finder, findsOneWidget, reason: 'le widget $key est introuvable');
    expect(
      finder.hitTestable(),
      findsOneWidget,
      reason:
          'le clic sur $key ne traverse pas le panneau : $key est recouvert',
    );
  }
}
