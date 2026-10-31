import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: la plateforme simulée est Linux
///
/// La démo tourne sous Linux. Par défaut `flutter_test` simule Android : la
/// densité visuelle et la taille de cible tactile des boutons Material
/// seraient celles d'un téléphone et fausseraient la mesure des cibles de la
/// régie. À placer avant le lancement de l'app (le thème est construit alors).
Future<void> laPlateformeSimuleeEstLinux(WidgetTester tester) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.linux;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
}
