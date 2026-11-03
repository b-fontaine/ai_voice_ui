import 'package:flutter_test/flutter_test.dart';

import 'package:flutter/widgets.dart';

/// Usage: un seul cadre de génération est affiché
Future<void> unSeulCadreDeGenerationEstAffiche(WidgetTester tester) async {
  final Finder frames = find.byWidgetPredicate((Widget w) {
    final Key? key = w.key;
    return key is ValueKey<String> &&
        RegExp(r'^generation-frame-[^-]+$').hasMatch(key.value);
  });
  final List<String> names = <String>[
    for (final Element e in frames.evaluate())
      (e.widget.key! as ValueKey<String>).value,
  ];
  expect(
    names,
    hasLength(1),
    reason:
        'un seul cadre actif (la dernière surface créée, pdr-0088 F11) : $names',
  );
}
