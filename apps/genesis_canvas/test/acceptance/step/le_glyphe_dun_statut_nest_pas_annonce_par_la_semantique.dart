import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

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
  final SemanticsOwner? owner = tester.binding.rootPipelineOwner.semanticsOwner;
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
