import 'package:flutter/material.dart';

import 'scene_theme.dart';

/// Texte affiché en capitales (`text-transform: uppercase` du design system),
/// sans que la donnée ni la sémantique changent.
///
/// Le texte est mis en capitales **à l'affichage seulement** (`toUpperCase`) :
/// la chaîne d'origine reste la donnée (backend, clés, tests de contenu) et
/// devient le libellé `Semantics` ; le texte affiché est exclu de la
/// sémantique pour que le lecteur d'écran n'annonce pas deux fois le mot.
///
/// Usage : étiquettes `label`, puces de statut, en-têtes de tableau, segments
/// d'actes. Jamais les chaînes de données (valeurs, noms de critères,
/// verbatims, transcription). Un test qui cherche un tel libellé utilise
/// `findTextIgnoringCase` (`testing_real_fonts`) ou la sémantique, jamais
/// `find.text` avec la casse d'origine.
class DsCaps extends StatelessWidget {
  const DsCaps(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  /// Texte d'origine, dans sa casse de donnée.
  final String text;

  /// Style du texte ; le style `label` du thème par défaut.
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: text,
      child: ExcludeSemantics(
        child: Text(
          text.toUpperCase(),
          style: style ?? SceneTheme.of(context).label,
          maxLines: maxLines,
          overflow: overflow,
          textAlign: textAlign,
        ),
      ),
    );
  }
}
