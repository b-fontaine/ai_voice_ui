import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_canvas/widgets/top_bar/top_bar.dart';
import 'package:testing_real_fonts/testing_real_fonts.dart';

import '../support/page_rig.dart';

/// L'option de police de `PageRig` : la page montée avec les polices réelles
/// affiche son texte en Noto Sans (et non en Ahem), ce qui rend mesurable un
/// libellé tronqué.
void main() {
  setUpAll(loadRealFonts);

  testWidgets('la page montée avec une police réelle l\'applique au texte', (
    tester,
  ) async {
    final rig = PageRig(tester);
    await rig.mount(
      tester,
      fontFamily: realFontFamily,
      fontFamilyFallback: realFontFallback,
    );

    final families = <String?>{
      for (final p in tester.renderObjectList<RenderParagraph>(
        find.descendant(
          of: find.byType(TopBar),
          matching: find.byType(RichText),
        ),
      ))
        p.text.style?.fontFamily,
    };
    expect(families, contains(realFontFamily));
    expect(tester.takeException(), isNull);
  });
}
