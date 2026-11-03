import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'act_indicator_finder.dart';

void main() {
  testWidgets('findActIndicatorLabel lit le libellé du Semantics du bouton', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Semantics(
          label: 'Acte 2/3 · Transformer',
          button: true,
          excludeSemantics: true,
          child: TextButton(
            key: const Key('act-indicator'),
            onPressed: () {},
            child: const Text('02 Transformer'),
          ),
        ),
      ),
    );

    expect(findActIndicatorLabel('acte 2/3'), findsOneWidget);
    expect(findActIndicatorLabel('Acte 2/3 · Transformer'), findsOneWidget);
    expect(findActIndicatorLabel('Acte 1/3'), findsNothing);
  });
}
