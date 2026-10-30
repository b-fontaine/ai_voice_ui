import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_canvas/widgets/replay_bar/replay_bar.dart';

void main() {
  testWidgets('emplacement du rejeu : libellé REJEU et commandes inactives', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 340, height: 140, child: ReplayBar()),
        ),
      ),
    );

    expect(find.byKey(const Key('replay-bar')), findsOneWidget);
    expect(find.text('REJEU'), findsOneWidget);
    final controls = find.descendant(
      of: find.byKey(const Key('replay-bar')),
      matching: find.byType(IconButton),
    );
    expect(controls.evaluate().length, 3);
    for (final control in tester.widgetList<IconButton>(controls)) {
      expect(control.onPressed, isNull, reason: 'inactif jusqu\'à J6');
    }
  });
}
