/// Lecture d'un pourcentage écrit à la française (« 99,43 % », « ≥ 99,50 % »).
///
/// Les données du KPI sont des chaînes (pdr-0088 F3) : cette lecture sert
/// seulement à placer la jauge, la marque de seuil et le compteur. Elle ne
/// doit **jamais** être appelée sur `delta` ni sur `statusLabel`, et un texte
/// illisible n'est jamais corrigé ni deviné (`null`).
library;

/// Un pourcentage lu dans un texte, avec les morceaux du texte d'origine.
///
/// `prefix + number + suffix` redonne exactement le texte lu : l'affichage
/// (compteur, valeur et unité) peut ainsi reconstruire la chaîne de la donnée
/// sans la modifier.
class FrPercent {
  const FrPercent._({
    required this.prefix,
    required this.number,
    required this.suffix,
    required this.value,
  });

  // Les espaces simples, insécables (U+00A0), fines insécables (U+202F) et
  // fines (U+2009) tiennent dans `\s` de Dart.
  static final RegExp _pattern = RegExp(
    r'^(\s*(?:≥\s*)?)(\d{1,3}(?:,\d+)?)(\s*%\s*)$',
  );

  /// Ce qui précède le nombre : espaces et « ≥ » éventuels.
  final String prefix;

  /// Le nombre, tel qu'écrit (virgule décimale).
  final String number;

  /// Ce qui suit le nombre : l'unité « % » et ses espaces.
  final String suffix;

  /// Valeur numérique du nombre (99,43 vaut 99.43).
  final double value;

  /// Lit [text], ou `null` si ce n'est pas « n % » ni « ≥ n % ».
  static FrPercent? tryParse(String text) {
    final RegExpMatch? match = _pattern.firstMatch(text);
    if (match == null) return null;
    final String number = match.group(2)!;
    final double? value = double.tryParse(number.replaceAll(',', '.'));
    if (value == null) return null;
    return FrPercent._(
      prefix: match.group(1)!,
      number: number,
      suffix: match.group(3)!,
      value: value,
    );
  }
}

/// La valeur de « 99,43 % » ou de « ≥ 99,50 % » ; `null` pour tout le reste.
double? parseFrPercent(String text) => FrPercent.tryParse(text)?.value;
