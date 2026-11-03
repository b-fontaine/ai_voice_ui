import 'package:flutter/material.dart';

import 'ds_caps.dart';
import 'scene_theme.dart';

/// En-tête de panneau (`.gc-panel__head`) : une étiquette ou un titre à
/// gauche, un statut ou un élément à droite, centrés verticalement.
///
/// L'espacement minimal entre les deux côtés est de 12 px et la marge basse de
/// 14 px, comme dans le design system. [DsPanelHead.new] affiche une étiquette
/// en capitales (style `label`, via [DsCaps]) ; [DsPanelHead.title] affiche un
/// titre libre dans le style `title`, sans capitales. Le côté gauche se
/// tronque avant de repousser [trailing], sauf avec [wrap] (retour à la ligne).
class DsPanelHead extends StatelessWidget {
  const DsPanelHead({
    super.key,
    required String this.label,
    this.trailing,
    this.wrap = false,
  }) : title = null;

  const DsPanelHead.title({
    super.key,
    required String this.title,
    this.trailing,
    this.wrap = false,
  }) : label = null;

  /// Espace minimal entre le côté gauche et [trailing].
  static const double gap = 12;

  /// Marge sous l'en-tête.
  static const double bottomMargin = 14;

  /// Étiquette en capitales (constructeur par défaut).
  final String? label;

  /// Titre libre (constructeur [DsPanelHead.title]).
  final String? title;

  /// Statut ou élément affiché à droite.
  final Widget? trailing;

  /// Vrai : l'étiquette ou le titre passe à la ligne au lieu de se tronquer
  /// (un libellé de donnée ne doit jamais être coupé par une ellipse).
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    final String? caption = label;
    final Widget left = caption != null
        ? DsCaps(
            caption,
            maxLines: wrap ? null : 1,
            overflow: wrap ? TextOverflow.clip : TextOverflow.ellipsis,
          )
        : Text(
            title!,
            style: theme.title,
            maxLines: wrap ? null : 1,
            overflow: wrap ? TextOverflow.clip : TextOverflow.ellipsis,
          );
    final Widget? right = trailing;
    return Padding(
      padding: const EdgeInsets.only(bottom: bottomMargin),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Flexible(child: left),
          if (right != null) ...<Widget>[const SizedBox(width: gap), right],
        ],
      ),
    );
  }
}
