import 'package:flutter/material.dart';

import 'scene_radius.dart';
import 'scene_theme.dart';

/// Épaisseur de l'anneau de focus clavier.
const double _focusRingWidth = 2;

/// Style d'une cible de pointage transparente (D-05, NFR-05) : le visuel
/// (fond, bordure) est dessiné par l'enfant du bouton, la cible n'a que la
/// hauteur minimale [height] (48 points) et ne porte aucune marge.
///
/// Le focus clavier reste visible (pdr-0084 U4) : un anneau `signal`
/// (`theme.accent`) de 2 points entoure la cible sous `WidgetState.focused` ;
/// sans focus, aucune bordure. `line-strong` n'est jamais une bordure de
/// bouton. La densité visuelle est standard : sans cela, la densité de la
/// plateforme réduirait la cible.
ButtonStyle sceneTargetStyle(
  SceneTheme theme, {
  OutlinedBorder shape = const RoundedRectangleBorder(
    borderRadius: SceneRadius.borderMd,
  ),
  double height = 48,
}) {
  final Color clear = theme.surface300.withValues(alpha: 0);
  return ButtonStyle(
    backgroundColor: WidgetStatePropertyAll<Color>(clear),
    overlayColor: WidgetStatePropertyAll<Color>(clear),
    shadowColor: WidgetStatePropertyAll<Color>(clear),
    surfaceTintColor: WidgetStatePropertyAll<Color>(clear),
    visualDensity: VisualDensity.standard,
    minimumSize: WidgetStatePropertyAll<Size>(Size(0, height)),
    padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(EdgeInsets.zero),
    shape: WidgetStatePropertyAll<OutlinedBorder>(shape),
    side: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
      return states.contains(WidgetState.focused)
          ? BorderSide(color: theme.accent, width: _focusRingWidth)
          : BorderSide.none;
    }),
  );
}
