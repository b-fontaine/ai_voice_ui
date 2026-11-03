import 'package:flutter_test/flutter_test.dart';

import '../support/fidelity_harness.dart';

/// Usage: l'élément {'generation-frame-crashes'} est invisible ou absent
Future<void> lelementEstInvisibleOuAbsent(
  WidgetTester tester,
  String element,
) async {
  if (!Fidelity.present(element)) return;
  expect(
    Fidelity.opacity(element),
    lessThan(0.01),
    reason: "l'élément « $element » devrait avoir disparu",
  );
}
