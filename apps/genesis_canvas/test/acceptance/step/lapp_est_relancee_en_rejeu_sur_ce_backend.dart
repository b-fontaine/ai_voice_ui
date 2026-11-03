import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

import 'package:flutter/widgets.dart';

/// Usage: l'app est relancée en rejeu {'act3-replay'} sur ce backend
Future<void> lappEstRelanceeEnRejeuSurCeBackend(
  WidgetTester tester,
  String scenario,
) async {
  // Une nouvelle app remplace l'ancienne : on démonte d'abord celle du
  // contexte, sans quoi le même `State` serait réutilisé avec l'ancien scénario.
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  await SessionHarness.launchApp(tester, scenario: scenario);
}
