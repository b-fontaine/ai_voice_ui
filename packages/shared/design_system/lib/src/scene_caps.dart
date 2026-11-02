import 'package:flutter/widgets.dart';

/// Chaîne [text] en capitales, pour l'**affichage** d'une étiquette HUD
/// (style `label`). La donnée d'origine n'est jamais modifiée.
String sceneCaps(String text) => text.toUpperCase();

/// Étiquette HUD en capitales : le texte affiché est en capitales, le texte
/// d'origine reste le libellé de `Semantics` (les technologies d'assistance
/// lisent « Catalogue », pas une suite de lettres capitales).
///
/// Flutter n'a pas de `text-transform` : les capitales sont posées ici, à
/// l'affichage, et nulle part dans les données.
class SceneCapsText extends StatelessWidget {
  const SceneCapsText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.softWrap,
    this.textAlign,
  });

  /// Texte d'origine (casse conservée).
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) => Text(
    sceneCaps(text),
    semanticsLabel: text,
    style: style,
    maxLines: maxLines,
    overflow: overflow,
    softWrap: softWrap,
    textAlign: textAlign,
  );
}
