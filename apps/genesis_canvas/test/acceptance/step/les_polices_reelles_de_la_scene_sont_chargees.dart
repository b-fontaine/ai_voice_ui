import 'package:flutter_test/flutter_test.dart';

import '../support/design_harness.dart';

/// Usage: les polices réelles de la scène sont chargées
///
/// Noto Sans (texte courant) et DejaVu Sans (repli de « ★ ») remplacent la
/// police de test (Ahem) : sans elles, « tronqué » ne se mesure pas (toutes les
/// lignes ont la hauteur nominale et chaque glyphe fait un carré). À placer
/// avant le lancement de l'app.
Future<void> lesPolicesReellesDeLaSceneSontChargees(WidgetTester tester) async {
  DesignHarness.reset();
  await DesignHarness.ensureRealFonts();
}
