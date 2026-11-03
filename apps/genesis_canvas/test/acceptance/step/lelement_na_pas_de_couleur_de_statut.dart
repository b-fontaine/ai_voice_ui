import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

import '../support/fidelity_harness.dart';

/// Usage: l'élément {'kpi-delta-comparison-value'} n'a pas de couleur de statut
///
/// La couleur d'un statut vient de son code `ok|risk|blocking` (RG-09), jamais
/// du texte d'un écart (pdr-0064 D7, pdr-0088 F3) : le texte de l'élément et
/// chacune de ses parties sont neutres, même pour un écart négatif.
Future<void> lelementNaPasDeCouleurDeStatut(
  WidgetTester tester,
  String element,
) async {
  final Finder finder = Fidelity.one(element);
  final BuildContext context = tester.element(finder);
  final SceneTheme theme = SceneTheme.of(context);
  final Widget widget = tester.widget(finder);
  expect(widget, isA<Text>(), reason: '« $element » n\'est pas un Text');
  final Text text = widget as Text;
  final List<Color?> colors = <Color?>[];
  void collect(InlineSpan? span) {
    if (span is TextSpan) {
      colors.add(span.style?.color);
      span.children?.forEach(collect);
    }
  }

  colors.add(text.style?.color);
  collect(text.textSpan);
  final List<Color> status = <Color>[
    theme.okForeground,
    theme.riskForeground,
    theme.blockingForeground,
    theme.okBackground,
    theme.riskBackground,
    theme.blockingBackground,
  ];
  for (final Color? color in colors) {
    expect(
      status,
      isNot(contains(color)),
      reason: '« $element » porte une couleur de statut',
    );
  }
}
