import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

import '../support/design_harness.dart';

/// Usage: les polices réelles de la scène sont chargées
///
/// Noto Sans (texte courant) et DejaVu Sans (repli de « ★ ») remplacent la
/// police de test (Ahem) : sans elles, « tronqué » ne se mesure pas (toutes les
/// lignes ont la hauteur nominale et chaque glyphe fait un carré). À placer
/// avant le lancement de l'app. Les trois familles de l'app (Space Grotesk,
/// JetBrains Mono, DejaVu Sans, noms préfixés par le paquet) sont chargées par
/// le même appel, et les licences OFL sont enregistrées comme le fera `main()`.
Future<void> lesPolicesReellesDeLaSceneSontChargees(WidgetTester tester) async {
  DesignHarness.reset();
  await DesignHarness.ensureRealFonts();
  registerSceneFontLicenses();
}
