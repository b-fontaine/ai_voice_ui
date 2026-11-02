import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/scene_style_harness.dart';

/// Usage: les titres, légendes, libellés de boutons et textes courants de l'écran sont en police {'Space Grotesk'}
///
/// Textes dont le style est celui d'un rôle de mots du `SceneTheme` (`title`,
/// `body`, `button`, `transcript`).
Future<void>
lesTitresLegendesLibellesDeBoutonsEtTextesCourantsDeLecranSontEnPolice(
  WidgetTester tester,
  String family,
) async {
  final List<RenderParagraph> words = SceneStyleHarness.paragraphsOfRoles(
    tester,
    roles: SceneStyleHarness.wordRoles,
    otherRoles: SceneStyleHarness.dataRoles,
  );
  expect(words, isNotEmpty, reason: 'aucun texte de rôle « mot » repéré');
  final List<String> wrong = <String>[
    for (final RenderParagraph p in words)
      if (SceneStyleHarness.bareFamily(p.text.style?.fontFamily) != family)
        SceneStyleHarness.describeParagraph(p),
  ];
  expect(
    wrong,
    isEmpty,
    reason: 'mots hors police $family :\n${wrong.join('\n')}',
  );
}
