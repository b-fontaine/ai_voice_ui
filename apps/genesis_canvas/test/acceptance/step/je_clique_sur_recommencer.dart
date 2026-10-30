import 'package:flutter_test/flutter_test.dart';

import '../support/acte4_harness.dart';

/// Usage: je clique sur Recommencer
Future<void> jeCliqueSurRecommencer(WidgetTester tester) async {
  await Acte4Harness.press(tester, ReplayKeys.restart);
}
