import 'package:flutter_test/flutter_test.dart';

import '../../support/contrast.dart';
import '../support/fidelity_harness.dart';
import '../support/scene_palette.dart';

import 'package:flutter/widgets.dart';

/// Usage: tout texte visible de moins de {24} px est contrasté d'au moins {4.5} sur son fond réel
Future<void> toutTexteVisibleDeMoinsDePxEstContrasteDauMoinsSurSonFondReel(
  WidgetTester tester,
  num limit,
  num minimum,
) async {
  final List<(Element, SpanLeaf)> small = <(Element, SpanLeaf)>[
    for (final (Element e, SpanLeaf leaf) in Fidelity.visibleLeaves(tester))
      if ((leaf.style.fontSize ?? 0) < limit) (e, leaf),
  ];
  expect(
    small,
    isNotEmpty,
    reason:
        "aucun texte de moins de $limit px n'est affiché : l'échelle du "
        'design système (pdr-0087) n\'est pas appliquée, le contraste des '
        'petits textes n\'est pas mesurable',
  );
  final List<String> failing = <String>[];
  for (final (Element element, SpanLeaf leaf) in small) {
    final Color? color = leaf.style.color;
    if (color == null) {
      failing.add('${leaf.text} : texte sans couleur');
      continue;
    }
    final List<Color> backgrounds = Fidelity.backgroundsOf(element);
    double worst = double.infinity;
    for (final Color background in backgrounds) {
      worst = worst < 0
          ? worst
          : (contrast(Fidelity.over(color, background), background) < worst
                ? contrast(Fidelity.over(color, background), background)
                : worst);
    }
    if (worst < minimum) {
      failing.add(
        '${leaf.text} (${leaf.style.fontSize} px, ${ScenePalette.describe(color)}) : '
        '${worst.toStringAsFixed(2)}:1',
      );
    }
  }
  expect(
    failing,
    isEmpty,
    reason:
        'textes de moins de $limit px sous $minimum:1 :\n${failing.join('\n')}',
  );
}
