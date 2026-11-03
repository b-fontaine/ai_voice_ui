import 'package:flutter_test/flutter_test.dart';

import '../support/fidelity_harness.dart';

/// Usage: tout texte visible de l'écran est dans l'échelle de texte du design system
Future<void> toutTexteVisibleDeLecranEstDansLechelleDeTexteDuDesignSystem(
  WidgetTester tester,
) async {
  final List<String> outside = <String>[
    for (final (_, SpanLeaf leaf) in Fidelity.visibleLeaves(tester))
      if (leaf.style.fontSize == null ||
          !Fidelity.scaleSizes.contains(leaf.style.fontSize))
        leaf.toString(),
  ];
  expect(
    outside,
    isEmpty,
    reason:
        "textes visibles hors de l'échelle du design système "
        '(${Fidelity.scaleSizes.toList()..sort()}) :\n${outside.join('\n')}',
  );
}
