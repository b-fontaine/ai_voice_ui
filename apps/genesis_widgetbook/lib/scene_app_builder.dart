import 'package:flutter/material.dart';
import 'package:shared_design_system/shared_design_system.dart' show SceneTheme;

/// Thème Material du catalogue : sombre, avec le [SceneTheme] installé comme
/// extension, comme dans l'app (un seul thème, RG-09).
ThemeData sceneThemeData() {
  const scene = SceneTheme.dark();
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: scene.background,
    extensions: const <ThemeExtension<dynamic>>[scene],
  );
}

/// Enveloppe chaque story dans le thème de scène.
///
/// La marge de 8 px évite que le contenu touche le bord du cliché, sans quoi
/// les règles d'accessibilité ignorent les nœuds de bordure (spike
/// ds-widgetbook-4-spike, contournement 3).
Widget sceneAppBuilder(BuildContext context, Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: sceneThemeData(),
    home: Material(
      color: const SceneTheme.dark().background,
      child: Padding(padding: const EdgeInsets.all(8), child: child),
    ),
  );
}
