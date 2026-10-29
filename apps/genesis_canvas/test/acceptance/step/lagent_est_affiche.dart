import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: l'agent {'Qualité'} est affiché {'en cours'}
Future<void> lagentEstAffiche(
  WidgetTester tester,
  String agent,
  String state,
) async {
  final row = find.descendant(
    of: find.byKey(const Key('agents-rail')),
    matching: find.byKey(Key('agent-$agent')),
  );
  await SessionHarness.waitFor(
    tester,
    row,
    "agents-rail doit contenir la ligne de l'agent $agent",
  );
  await SessionHarness.waitFor(
    tester,
    find.descendant(of: row, matching: find.text(state)),
    "l'agent $agent doit afficher l'état « $state »",
  );
}
