import 'package:flutter_test/flutter_test.dart';

import '../support/design_harness.dart';

/// Usage: j'avance par pas de {10} millisecondes jusqu'à ce que les composants de la surface {'checklist'} soient affichés
///
/// Attend d'abord que la surface soit absente (le rejeu vide puis reconstruit le
/// tableau ; choisir une surface qui arrive tard),
/// puis que le moteur de rendu de la surface revienne : la mesure suit ainsi
/// la première image de l'apparition rejouée, pas le contenu du direct.
Future<void>
javanceParPasDeMillisecondesJusquaCeQueLesComposantsDeLaSurfaceSoientAffiches(
  WidgetTester tester,
  num stepMs,
  String surface,
) async {
  const limit = Duration(seconds: 30);
  final step = Duration(milliseconds: stepMs.toInt());
  var elapsed = Duration.zero;
  var cleared = false;
  while (true) {
    final shown = DesignHarness.contentOf(surface).evaluate().isNotEmpty;
    if (!shown) cleared = true;
    if (shown && cleared) return;
    if (elapsed >= limit) {
      fail(
        'les composants de la surface $surface ne sont pas rejoués après '
        '${limit.inSeconds} s simulées (canevas vidé : $cleared)',
      );
    }
    await tester.pump(step);
    elapsed += step;
  }
}
