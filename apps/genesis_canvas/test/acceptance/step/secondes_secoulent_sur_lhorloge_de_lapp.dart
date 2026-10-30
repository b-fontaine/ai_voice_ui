import 'package:flutter_test/flutter_test.dart';

import '../support/acte4_harness.dart';

/// Usage: {60} secondes s'écoulent sur l'horloge de l'app
Future<void> secondesSecoulentSurLhorlogeDeLapp(
  WidgetTester tester,
  num seconds,
) async {
  Acte4Harness.clock.advance(Acte4Harness.seconds(seconds));
}
