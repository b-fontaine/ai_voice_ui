import 'package:flutter_test/flutter_test.dart';

import '../support/session_harness.dart';

/// Usage: le serveur émet la surface {'kpi'} en trois temps
Future<void> leServeurEmetLaSurfaceEnTroisTemps(
  WidgetTester tester,
  String surface,
) async {
  final session = SessionHarness.backend.lastSessionId!;
  await SessionHarness.onServer(
    tester,
    () => SessionHarness.backend.emitGenesisSurface(session, surface),
  );
}
