import 'package:flutter_test/flutter_test.dart';

import '../support/fidelity_harness.dart';

import 'package:flutter/painting.dart';

/// Usage: l'élément {'generation-frame-checklist'} entoure l'élément {'surface-checklist'}
Future<void> lelementEntoureLelement(
  WidgetTester tester,
  String outer,
  String inner,
) async {
  final Rect frame = Fidelity.rect(tester, outer).inflate(0.5);
  final Rect target = Fidelity.rect(tester, inner);
  expect(
    frame.contains(target.topLeft) && frame.contains(target.bottomRight),
    isTrue,
    reason: "« $outer » ($frame) doit entourer « $inner » ($target)",
  );
}
