import 'package:flutter/widgets.dart';
import 'package:shared_design_system/shared_design_system.dart'
    show SceneMotionScope, ScenePanel;

/// Enveloppe commune des stories des briques : les briques n'ont plus de fond
/// propre, c'est le panneau de la cellule (`ScenePanel`, marge de 16 px et
/// décoration en retrait de 4 px) qui le pose dans l'app. Animations coupées
/// pour des captures stables.
Widget dsStorySetup(Widget child) =>
    SceneMotionScope(disabled: true, child: ScenePanel(child: child));
