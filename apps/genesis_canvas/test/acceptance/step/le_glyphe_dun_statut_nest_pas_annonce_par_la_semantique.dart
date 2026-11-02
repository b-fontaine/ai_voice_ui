import 'package:flutter/widgets.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shared_design_system/shared_design_system.dart'
    show DsStatusChip;

import '../support/acte4_harness.dart';

/// Usage: le glyphe d'un statut n'est pas annoncé par la sémantique
///
/// Le glyphe ✓ est affiché (un `Text` à l'écran) mais aucun nœud de
/// l'arbre sémantique ne le porte dans son libellé, sa valeur ou son indice :
/// le mot du statut suffit au lecteur d'écran.
Future<void> leGlypheDunStatutNestPasAnnonceParLaSemantique(
  WidgetTester tester,
) async {
  const String glyph = '✓';
  expect(
    find.text(glyph),
    findsWidgets,
    reason: 'aucun glyphe $glyph affiché : rien à exclure de la sémantique',
  );
  // L'arbre sémantique n'est actif qu'une fois demandé, puis calculé par une
  // image ; la fin du scénario le libère.
  Acte4Harness.ensureSemantics(tester);
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 16));
  final Finder chips = find.byType(DsStatusChip);
  expect(chips, findsWidgets, reason: 'aucun statut affiché');
  final List<String> announced = <String>[];
  void visit(SemanticsNode node) {
    for (final String text in <String>[
      node.label,
      node.value,
      node.hint,
      node.tooltip,
    ]) {
      if (text.contains(glyph)) announced.add(text);
    }
    node.visitChildren((SemanticsNode child) {
      visit(child);
      return true;
    });
  }

  // Seuls les descendants d'un `DsStatusChip` sont examinés : le « fait ✓ » de
  // la Barre d'actions porte légitimement le glyphe dans son libellé.
  for (final Element chip in chips.evaluate()) {
    final Finder words = find.descendant(
      of: find.byWidget(chip.widget),
      matching: find.byType(Text),
    );
    for (final Element word in words.evaluate()) {
      visit(tester.getSemantics(find.byWidget(word.widget)));
    }
  }
  expect(
    announced,
    isEmpty,
    reason: 'le glyphe $glyph est annoncé par : $announced',
  );
}
