import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

void main() {
  test('sceneCaps met en capitales à l\'affichage, accents compris', () {
    expect(sceneCaps('Agents a2a'), 'AGENTS A2A');
    expect(sceneCaps('Utilisés · été'), 'UTILISÉS · ÉTÉ');
  });

  testWidgets(
    'SceneCapsText affiche les capitales et garde le texte d\'origine '
    'pour les technologies d\'assistance',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SceneCapsText('Catalogue · 4 / 6 utilisés'),
        ),
      );
      expect(find.text('CATALOGUE · 4 / 6 UTILISÉS'), findsOneWidget);
      expect(find.text('Catalogue · 4 / 6 utilisés'), findsNothing);
      expect(
        tester.getSemantics(find.byType(SceneCapsText)).label,
        'Catalogue · 4 / 6 utilisés',
      );
      handle.dispose();
    },
  );

  testWidgets('SceneCapsText applique le style et les limites donnés', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: SceneCapsText(
          'Rejeu',
          style: TextStyle(fontSize: 30),
          maxLines: 1,
        ),
      ),
    );
    final Text text = tester.widget<Text>(find.text('REJEU'));
    expect(text.style?.fontSize, 30);
    expect(text.maxLines, 1);
  });
}
