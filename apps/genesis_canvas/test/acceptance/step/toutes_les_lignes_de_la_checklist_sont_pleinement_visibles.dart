import 'package:flutter_test/flutter_test.dart';

import '../support/fidelity_harness.dart';

/// Usage: toutes les lignes de la checklist sont pleinement visibles
Future<void> toutesLesLignesDeLaChecklistSontPleinementVisibles(
  WidgetTester tester,
) async {
  var index = 0;
  Fidelity.one('checklist-row-0');
  while (Fidelity.present('checklist-row-$index')) {
    expect(
      Fidelity.opacity('checklist-row-$index'),
      greaterThanOrEqualTo(0.99),
      reason: 'la ligne $index de la checklist devrait être pleinement visible',
    );
    index++;
  }
}
