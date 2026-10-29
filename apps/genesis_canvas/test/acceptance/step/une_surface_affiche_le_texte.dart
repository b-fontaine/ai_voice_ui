import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';

/// Usage: une surface affiche le texte {'Sessions sans crash'}
Future<void> uneSurfaceAfficheLeTexte(WidgetTester tester, String text) async {
  expect(find.byType(Surface), findsOneWidget, reason: 'une surface attendue');
  expect(
    find.descendant(of: find.byType(Surface), matching: find.text(text)),
    findsOneWidget,
  );
}
