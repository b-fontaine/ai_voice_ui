import 'package:flutter/material.dart';
import 'package:shared_design_system/shared_design_system.dart'
    show SceneRadius, SceneTheme, sceneTextStyle;

/// Bouton `gc-btn--sm` du design system dans une cible de pointage de 48
/// points (NFR-05, D-05).
///
/// Le bouton Material ([buttonKey]) porte la cible : au moins
/// [targetHeight] points de haut, fond et bordure transparents. Le visuel de
/// [visualHeight] points (clé [visualKey]) est centré dedans : rayon `md`,
/// marges de 12, texte `button`, bordure `ink-muted` de 1 point (jamais
/// `line-strong`, 2,3:1, pdr-0084 U4). Le bouton plein a le fond `surface-300` ;
/// le bouton fantôme ([ghost], `gc-btn--ghost`) n'a pas de fond. [recording]
/// ajoute le point d'enregistrement (`gc-btn--rec::before`, 8 points `nogo`,
/// clé `mic-rec-dot`).
///
/// La logique reste chez l'appelant : [onPressed] `null` désactive le bouton.
/// La sémantique de bouton porte [semanticsLabel] (par défaut [label]).
class SmButton extends StatelessWidget {
  const SmButton({
    super.key,
    required this.buttonKey,
    required this.visualKey,
    required this.label,
    required this.onPressed,
    this.semanticsLabel,
    this.ghost = false,
    this.recording = false,
  });

  /// Hauteur du visuel (`gc-btn--sm`).
  static const double visualHeight = 34;

  /// Hauteur minimale de la cible de pointage.
  static const double targetHeight = 48;

  /// Diamètre du point d'enregistrement.
  static const double recDotSize = 8;

  /// Clé du bouton Material, c'est-à-dire de la cible.
  final Key buttonKey;

  /// Clé du visuel de [visualHeight] points.
  final Key visualKey;

  final String label;
  final String? semanticsLabel;
  final VoidCallback? onPressed;
  final bool ghost;
  final bool recording;

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    final bool enabled = onPressed != null;
    final TextStyle textStyle = sceneTextStyle(
      context,
      theme.button,
    ).copyWith(color: enabled ? theme.textPrimary : theme.neutralForeground);
    final Color clear = theme.background.withValues(alpha: 0);
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticsLabel ?? label,
      excludeSemantics: true,
      child: FilledButton(
        key: buttonKey,
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: clear,
          disabledBackgroundColor: clear,
          foregroundColor: theme.textPrimary,
          disabledForegroundColor: theme.neutralForeground,
          overlayColor: clear,
          shadowColor: clear,
          surfaceTintColor: clear,
          visualDensity: VisualDensity.standard,
          minimumSize: const Size(targetHeight, targetHeight),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: SceneRadius.borderMd),
        ),
        child: SizedBox(
          key: visualKey,
          height: visualHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: ghost ? null : theme.surface300,
              borderRadius: SceneRadius.borderMd,
              border: Border.all(color: theme.textSecondary),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (recording) ...<Widget>[
                    DecoratedBox(
                      key: const Key('mic-rec-dot'),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.blockingForeground,
                      ),
                      child: const SizedBox.square(dimension: recDotSize),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(label, maxLines: 1, style: textStyle),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
