import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_backend.dart';
import '../support/session_harness.dart';

/// Usage: le faux backend en mode {'unreachable'}
Future<void> leFauxBackendEnMode(WidgetTester tester, String mode) async {
  switch (mode) {
    case 'unreachable':
      await tester.runAsync(SessionHarness.backend.stopListening);
    case 'rate-limited':
      SessionHarness.backend.postMode = PostMode.rateLimited;
    case 'bad-gateway':
      SessionHarness.backend.postMode = PostMode.badGateway;
    default:
      fail('mode de faux backend inconnu : $mode');
  }
}
