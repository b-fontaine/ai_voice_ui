import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_canvas/widgets/top_bar/top_bar.dart';
import 'package:shared_design_system/shared_design_system.dart' show SceneFonts;
import 'package:testing_real_fonts/testing_real_fonts.dart';

import '../support/page_rig.dart';

/// L'option de police de `PageRig` : la page montée avec les polices réelles
/// affiche son texte dans les polices de la scène (Space Grotesk, JetBrains
/// Mono), chargées par `loadRealFonts`, et non en Ahem, ce qui rend mesurable
/// un libellé tronqué. Les styles de `SceneTheme` portent leur famille (U11) :
/// la famille du thème Material ne sert qu'aux textes sans style de scène.
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
    expect(families, contains(SceneFonts.sans));
    expect(families, contains(SceneFonts.mono));
    expect(tester.takeException(), isNull);
  });
}
