import 'package:flutter/widgets.dart';

/// Largeur d'une ligne de texte sur une seule ligne, sans contrainte, telle
/// que la rendrait un `Text` placé dans [context].
///
/// Sert à répartir la largeur d'une ligne entre des colonnes dont on veut
/// afficher le contenu en entier.
double measureTextWidth(BuildContext context, String text, TextStyle style) {
  final TextPainter painter = TextPainter(
    // Même résolution de style que `Text` : le style par défaut du contexte
    // (espacement des lettres, famille) entre dans la largeur.
    text: TextSpan(
      text: text,
      style: DefaultTextStyle.of(context).style.merge(style),
    ),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final double width = painter.width;
  painter.dispose();
  return width;
}
