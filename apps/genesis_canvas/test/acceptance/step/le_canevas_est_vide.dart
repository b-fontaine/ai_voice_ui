import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';

/// Usage: le canevas est vide
Future<void> leCanevasEstVide(WidgetTester tester) async {
  expect(
    find.byKey(const Key('canvas-board')),
    findsOneWidget,
    reason: 'le canevas (canvas-board) doit exister',
  );
  expect(find.byType(Surface), findsNothing);
}
