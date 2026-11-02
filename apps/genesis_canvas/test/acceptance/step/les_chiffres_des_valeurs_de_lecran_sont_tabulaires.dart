import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/scene_style_harness.dart';

/// Usage: les chiffres des valeurs de l'écran sont tabulaires
///
/// Les textes aux rôles `value` et `data` qui portent un chiffre activent
/// `FontFeature.tabularFigures()`.
Future<void> lesChiffresDesValeursDeLecranSontTabulaires(
  WidgetTester tester,
) async {
  final List<RenderParagraph> numeric =
      SceneStyleHarness.paragraphsOfRoles(
        tester,
        roles: const <String>['value', 'data'],
        otherRoles: SceneStyleHarness.wordRoles,
      ).where((RenderParagraph p) {
        return RegExp(r'\d').hasMatch(p.text.toPlainText());
      }).toList();
  expect(
    numeric,
    isNotEmpty,
    reason: 'aucune valeur chiffrée de rôle value ou data repérée',
  );
  final List<String> wrong = <String>[
    for (final RenderParagraph p in numeric)
      if (!(p.text.style?.fontFeatures ?? const <FontFeature>[]).contains(
        const FontFeature.tabularFigures(),
      ))
        '« ${p.text.toPlainText()} » : fontFeatures '
            '${p.text.style?.fontFeatures}',
  ];
  expect(
    wrong,
    isEmpty,
    reason: 'chiffres non tabulaires :\n${wrong.join('\n')}',
  );
}
