import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

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
  final SemanticsOwner? owner =
      tester.binding.renderViews.first.owner?.semanticsOwner;
  expect(owner, isNotNull, reason: "l'arbre sémantique n'est pas actif");
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

  visit(owner!.rootSemanticsNode!);
  expect(
    announced,
    isEmpty,
    reason: 'le glyphe $glyph est annoncé par : $announced',
  );
}
