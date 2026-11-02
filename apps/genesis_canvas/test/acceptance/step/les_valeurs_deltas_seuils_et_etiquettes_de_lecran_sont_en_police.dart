import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/scene_style_harness.dart';

/// Usage: les valeurs, deltas, seuils et étiquettes de l'écran sont en police {'JetBrains Mono'}
///
/// Les textes « données » sont ceux dont le style est celui d'un rôle de
/// données du `SceneTheme` (`value`, `data`, `label`, `verdict`), pas ceux dont
/// le contenu ressemble à un chiffre.
Future<void> lesValeursDeltasSeuilsEtEtiquettesDeLecranSontEnPolice(
  WidgetTester tester,
  String family,
) async {
  final List<RenderParagraph> data = SceneStyleHarness.paragraphsOfRoles(
    tester,
    roles: SceneStyleHarness.dataRoles,
    otherRoles: SceneStyleHarness.wordRoles,
  );
  expect(data, isNotEmpty, reason: 'aucun texte de rôle « donnée » repéré');
  final List<String> wrong = <String>[
    for (final RenderParagraph p in data)
      if (SceneStyleHarness.bareFamily(p.text.style?.fontFamily) != family)
        SceneStyleHarness.describeParagraph(p),
  ];
  expect(
    wrong,
    isEmpty,
    reason: 'données hors police $family :\n${wrong.join('\n')}',
  );
}
