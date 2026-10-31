import 'package:flutter_test/flutter_test.dart';

/// Usage: le voile {'Micro coupé'} est affiché
///
/// Voile posé par-dessus la phase de l'orbe (screen.md), cherché par texte :
/// le libellé fait partie du contrat visible.
Future<void> leVoileEstAffiche(WidgetTester tester, String label) async {
  await tester.pump();
  expect(
    find.text(label),
    findsWidgets,
    reason: 'le voile « $label » n\'est pas affiché',
  );
}
