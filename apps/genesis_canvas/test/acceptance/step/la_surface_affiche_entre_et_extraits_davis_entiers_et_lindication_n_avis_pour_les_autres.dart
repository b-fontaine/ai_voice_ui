import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/design_harness.dart';

/// Usage: la surface {'reviews'} affiche entre {1} et {2} extraits d'avis entiers et l'indication « + N avis » pour les autres
///
/// Les extraits portent la clé `review-excerpt-<i>` (existante). Le contrat
/// en fournit trois : en 3 x 2 (cellule de 624 x 302) seuls [min] à [max]
/// tiennent entiers, les autres sont annoncés par « + N avis », N étant leur
/// nombre.
Future<void>
laSurfaceAfficheEntreEtExtraitsDavisEntiersEtLindicationNAvisPourLesAutres(
  WidgetTester tester,
  String surface,
  num min,
  num max,
) async {
  const provided = 3;
  final cell = DesignHarness.surface(surface);
  expect(cell, findsOneWidget, reason: 'la surface $surface est absente');
  final shown = <int>[
    for (var i = 0; i < provided; i++)
      if (find
          .descendant(of: cell, matching: find.byKey(Key('review-excerpt-$i')))
          .evaluate()
          .isNotEmpty)
        i,
  ].length;
  expect(
    shown,
    inInclusiveRange(min, max),
    reason: '$shown extraits affichés en 3 x 2, entre $min et $max attendus',
  );
  final pattern = RegExp(r'^\+ (\d+) avis$');
  final hidden = <int>[
    for (final text in tester.widgetList<Text>(
      find.descendant(of: cell, matching: find.byType(Text)),
    ))
      if (pattern.firstMatch(text.data ?? '') case final match?)
        int.parse(match.group(1)!),
  ];
  expect(hidden, <int>[
    provided - shown,
  ], reason: 'l\'indication « + ${provided - shown} avis » doit être affichée');
}
