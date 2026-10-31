import 'package:flutter/widgets.dart';
import 'package:shared_design_system/shared_design_system.dart'
    show SceneTheme, sceneTextStyle;

/// Largeur d'une ligne de texte sur une seule ligne, sans contrainte, telle
/// que la rendrait un `Text` placé dans [context].
///
/// Sert à répartir la largeur d'une ligne entre des colonnes dont on veut
/// afficher le contenu en entier.
double measureTextWidth(BuildContext context, String text, TextStyle style) {
  final TextPainter painter = _painter(context, text, style, maxLines: 1)
    ..layout();
  final double width = painter.width;
  painter.dispose();
  return width;
}

/// Hauteur d'un paragraphe de [text] à la largeur [maxWidth], telle que la
/// rendrait un `Text` sans limite de lignes placé dans [context] : le texte
/// passe à la ligne, jamais d'ellipse.
///
/// Sert à calculer combien de lignes à hauteur variable tiennent dans une
/// cellule bornée.
double measureTextHeight(
  BuildContext context,
  String text,
  TextStyle style,
  double maxWidth,
) {
  final TextPainter painter = _painter(context, text, style)
    ..layout(maxWidth: maxWidth);
  final double height = painter.height;
  painter.dispose();
  return height;
}

/// Hauteur d'une ligne de [style] : taille de police fois hauteur de ligne
/// (24 px et 1 quand ils sont absents).
double lineHeightOf(TextStyle style) =>
    (style.fontSize ?? 24) * (style.height ?? 1);

/// Dernière ligne d'une liste tronquée (« + N autres critères ») : texte
/// secondaire du thème de scène, aligné à gauche dans une hauteur fixée par
/// l'appelant (la même que celle réservée dans son budget).
class MoreLine extends StatelessWidget {
  const MoreLine({
    super.key,
    required this.textKey,
    required this.text,
    required this.height,
  });

  /// Clé posée sur le `Text`.
  final Key textKey;
  final String text;
  final double height;

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    return SizedBox(
      height: height,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          key: textKey,
          style: theme.body.copyWith(color: theme.textSecondary),
        ),
      ),
    );
  }
}

TextPainter _painter(
  BuildContext context,
  String text,
  TextStyle style, {
  int? maxLines,
}) => TextPainter(
  // Même résolution de style que `Text` : le style par défaut du contexte
  // (espacement des lettres, famille) entre dans la mesure.
  text: TextSpan(text: text, style: sceneTextStyle(context, style)),
  textDirection: Directionality.of(context),
  textScaler: MediaQuery.textScalerOf(context),
  maxLines: maxLines,
);
