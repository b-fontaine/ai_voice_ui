import 'package:flutter_test/flutter_test.dart';

import '../support/fidelity_harness.dart';
import '../support/scene_palette.dart';

import 'package:flutter/painting.dart';

/// Usage: aucun texte visible de moins de {24} px n'a la couleur {'ink-faint'}
Future<void> aucunTexteVisibleDeMoinsDePxNaLaCouleur(
  WidgetTester tester,
  num limit,
  String color,
) async {
  final Color forbidden = ScenePalette.named(color);
  final List<String> found = <String>[
    for (final (_, SpanLeaf leaf) in Fidelity.visibleLeaves(tester))
      if ((leaf.style.fontSize ?? 0) < limit &&
          leaf.style.color != null &&
          Fidelity.sameTint(leaf.style.color!, forbidden))
        leaf.toString(),
  ];
  expect(
    found,
    isEmpty,
    reason:
        'textes de moins de $limit px en $color (agentIdle a la même valeur ; '
        'pdr-0088 F12 : ink-muted) :\n${found.join('\n')}',
  );
}
