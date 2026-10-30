import 'package:flutter_test/flutter_test.dart';

import '../support/acte4_harness.dart';

/// Usage: j'attends la fin du rejeu
///
/// Avance le temps simulé pas à pas jusqu'à la dernière image (curseur au
/// bout, bouton « Lecture ») et note la durée écoulée.
Future<void> jattendsLaFinDuRejeu(WidgetTester tester) async {
  const limit = Duration(minutes: 2);
  var elapsed = Duration.zero;
  while (!Acte4Harness.isEnded(tester)) {
    if (elapsed >= limit) {
      fail('le rejeu n\'est pas terminé après ${limit.inSeconds} s simulées');
    }
    await tester.pump(Acte4Harness.tick);
    elapsed += Acte4Harness.tick;
  }
  Acte4Harness.durations.add(elapsed);
}
