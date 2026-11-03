import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testing_real_fonts/testing_real_fonts.dart';

void main() {
  testWidgets('trouve un texte affiché en capitales à partir de sa casse '
      'd\'origine, et inversement', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Column(
          children: <Widget>[Text('À RISQUE'), Text('Validé'), Text('autre')],
        ),
      ),
    );
    expect(findTextIgnoringCase('À risque'), findsOneWidget);
    expect(findTextIgnoringCase('VALIDÉ'), findsOneWidget);
    expect(findTextIgnoringCase('Bloquant'), findsNothing);
  });

  testWidgets('l\'égalité reste exacte hors casse, y compris pour Text.rich', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Column(
          children: <Widget>[
            Text('FLUX A2UI · LIVE'),
            Text.rich(
              TextSpan(
                text: 'CATALOGUE',
                children: [TextSpan(text: ' ·')],
              ),
            ),
          ],
        ),
      ),
    );
    expect(findTextIgnoringCase('Flux A2UI'), findsNothing);
    expect(findTextIgnoringCase('flux a2ui · live'), findsOneWidget);
    expect(findTextIgnoringCase('Catalogue ·'), findsOneWidget);
  });
}
