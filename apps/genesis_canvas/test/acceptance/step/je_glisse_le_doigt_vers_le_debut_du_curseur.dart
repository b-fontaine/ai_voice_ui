import 'package:flutter_test/flutter_test.dart';

import '../support/acte4_harness.dart';

/// Usage: je glisse le doigt vers le début du curseur
///
/// Quatre déplacements dont le total dépasse la largeur du curseur : la valeur
/// se cale sur le début. Le doigt reste posé.
Future<void> jeGlisseLeDoigtVersLeDebutDuCurseur(WidgetTester tester) async {
  final gesture = Acte4Harness.gesture!;
  final width = tester.getSize(find.byKey(ReplayKeys.slider)).width;
  for (var i = 0; i < 4; i++) {
    await gesture.moveBy(Offset(-width / 3, 0));
    await tester.pump();
  }
}
