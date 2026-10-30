import 'package:flutter_test/flutter_test.dart';

import '../support/acte4_harness.dart';

/// Usage: je choisis la vitesse {0.25}
Future<void> jeChoisisLaVitesse(WidgetTester tester, num speed) async {
  await Acte4Harness.press(tester, ReplayKeys.speed(speed));
}
