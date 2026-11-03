import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';
import 'package:testing_real_fonts/testing_real_fonts.dart';

Widget _host(Widget child) => MaterialApp(
  theme: ThemeData(extensions: const [SceneTheme.dark()]),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('le texte affiché est en capitales, la donnée est inchangée', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const DsCaps('À risque · Rejeu')));
    final Text shown = tester.widget<Text>(
      find.descendant(of: find.byType(DsCaps), matching: find.byType(Text)),
    );
    expect(shown.data, 'À RISQUE · REJEU');
  });

  testWidgets('la recherche d\'origine ne trouve plus le texte affiché, '
      'l\'aide insensible à la casse le trouve', (tester) async {
    await tester.pumpWidget(_host(const DsCaps('Bloquant')));
    expect(find.text('Bloquant'), findsNothing);
    expect(findTextIgnoringCase('Bloquant'), findsOneWidget);
  });

  testWidgets('la sémantique garde le texte d\'origine, une seule fois', (
    tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(const DsCaps('Bloquant')));
    expect(tester.getSemantics(find.byType(DsCaps)).label, 'Bloquant');
    expect(find.bySemanticsLabel('BLOQUANT'), findsNothing);
    expect(find.bySemanticsLabel('Bloquant'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('le style par défaut est `label` ; un style fourni l\'emporte', (
    tester,
  ) async {
    const SceneTheme theme = SceneTheme.dark();
    await tester.pumpWidget(_host(const DsCaps('Agents')));
    Text shown() => tester.widget<Text>(
      find.descendant(of: find.byType(DsCaps), matching: find.byType(Text)),
    );
    expect(shown().style, theme.label);

    await tester.pumpWidget(_host(DsCaps('Agents', style: theme.micro.badge)));
    expect(shown().style, theme.micro.badge);
  });
}
