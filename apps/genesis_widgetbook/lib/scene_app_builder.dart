import 'package:flutter/material.dart';
import 'package:shared_design_system/shared_design_system.dart'
    show SceneBackdrop, sceneMaterialTheme;

/// Enveloppe chaque story dans le thème de scène, sur le fond de l'app
/// (`SceneBackdrop` : fond void et grille de points).
///
/// Les polices Space Grotesk et JetBrains Mono viennent du thème
/// (`sceneMaterialTheme`) ; elles sont embarquées par le paquet
/// `shared_design_system` et se chargent donc avec le catalogue web comme avec
/// `testWidgetbook`.
///
/// La marge de 8 px évite que le contenu touche le bord du cliché, sans quoi
/// les règles d'accessibilité ignorent les nœuds de bordure (spike
/// ds-widgetbook-4-spike, contournement 3).
Widget sceneAppBuilder(BuildContext context, Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: sceneMaterialTheme(),
    home: Material(
      type: MaterialType.transparency,
      child: SceneBackdrop(
        child: Padding(padding: const EdgeInsets.all(8), child: child),
      ),
    ),
  );
}
