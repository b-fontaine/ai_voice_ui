import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/keys.dart';

/// Usage: chaque libellé de la liste des crashs tient sur {2} lignes au plus puis une ellipse
///
/// Le `Text` du libellé borne `maxLines` et coupe par une ellipse ; le rendu
/// réel ne dépasse pas ce nombre de lignes (pdr-0062 D9, A7).
Future<void> chaqueLibelleDeLaListeDesCrashsTientSurLignesAuPlusPuisUneEllipse(
  WidgetTester tester,
  num maxLines,
) async {
  for (var rank = 1; rank <= 5; rank++) {
    final label = find.byKey(AcceptanceKeys.crashLabel(rank));
    expect(label, findsOneWidget, reason: 'libellé du rang $rank absent');
    final text = tester.widget<Text>(label);
    expect(text.maxLines, maxLines, reason: 'maxLines du rang $rank');
    expect(
      text.overflow,
      TextOverflow.ellipsis,
      reason: 'le libellé du rang $rank doit finir par une ellipse',
    );
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: label, matching: find.byType(RichText)).first,
    );
    final lineHeight = paragraph.getFullHeightForCaret(
      const TextPosition(offset: 0),
    );
    expect(
      paragraph.size.height,
      lessThanOrEqualTo(maxLines * lineHeight + 1),
      reason: 'le libellé du rang $rank dépasse $maxLines lignes',
    );
  }
}
