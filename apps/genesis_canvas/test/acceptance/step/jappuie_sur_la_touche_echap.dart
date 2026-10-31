import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: j'appuie sur la touche Échap
///
/// Raccourci facultatif (pdr-0033) : l'évènement clavier part du focus de la
/// page, sans aucun clic préalable.
Future<void> jappuieSurLaToucheEchap(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pump();
}
