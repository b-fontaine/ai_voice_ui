import 'package:flutter_test/flutter_test.dart';

import 'package:flutter/widgets.dart';
import 'package:shared_design_system/shared_design_system.dart';

/// Usage: le mot de chaque puce de statut est en capitales
Future<void> leMotDeChaquePuceDeStatutEstEnCapitales(
  WidgetTester tester,
) async {
  final Finder chips = find.byType(DsStatusChip);
  expect(chips, findsWidgets, reason: 'aucune puce de statut affichée');
  for (var i = 0; i < chips.evaluate().length; i++) {
    final Finder chip = chips.at(i);
    final String label = tester.widget<DsStatusChip>(chip).label;
    final List<String> shown = <String>[
      for (final Element e
          in find.descendant(of: chip, matching: find.byType(Text)).evaluate())
        (e.widget as Text).data ??
            (e.widget as Text).textSpan?.toPlainText() ??
            '',
    ];
    expect(
      shown,
      contains(label.toUpperCase()),
      reason:
          "la puce « $label » doit afficher son mot en capitales (pdr-0088 F6) : $shown",
    );
  }
}
