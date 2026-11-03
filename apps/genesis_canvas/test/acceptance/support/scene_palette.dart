import 'dart:ui' show Color;

/// Couleurs du design system du 2026-11-02, écrites en dur d'après
/// `product/sources/design-system-2026-11-02/tokens.json` (jamais lues à
/// l'exécution : un jeton modifié par erreur dans l'app doit faire échouer le
/// scénario). Les fonds `*-ghost` portent leur alpha (`#RRGGBBAA` du CSS).
abstract final class ScenePalette {
  static const Color voidColor = Color(0xFF04060C);
  static const Color surface100 = Color(0xFF0A0F1E);
  static const Color surface200 = Color(0xFF101731);
  static const Color surface300 = Color(0xFF18213F);
  static const Color ink = Color(0xFFEAF0FF);
  static const Color signal = Color(0xFF3DE8FF);
  static const Color plasma = Color(0xFFA58BFF);
  static const Color baseline = Color(0xFF8592BB);
  static const Color inkMuted = Color(0xFF93A1CC);

  /// `ink-faint` (et `agentIdle`, de même valeur) : 4,35:1 au mieux, donc
  /// interdit à tout texte de moins de 24 px (pdr-0088 F12).
  static const Color inkFaint = Color(0xFF66739E);
  static const Color line = Color(0xFF1F2A4D);
  static const Color signalGhost = Color(0x1F3DE8FF);
  static const Color plasmaGhost = Color(0x24A58BFF);
  static const Color go = Color(0xFF3EF2A5);
  static const Color goGhost = Color(0x1C3EF2A5);
  static const Color warn = Color(0xFFFFC845);
  static const Color warnGhost = Color(0x1CFFC845);
  static const Color nogo = Color(0xFFFF5A76);
  static const Color nogoGhost = Color(0x1FFF5A76);

  /// Fonds réels sur lesquels une puce de statut peut se poser.
  static const List<Color> chipBases = <Color>[
    surface100,
    surface200,
    surface300,
  ];

  /// Couleurs de statut du design system, interdites aux séries.
  static const List<Color> statusColors = <Color>[go, warn, nogo];

  static const Map<String, Color> byName = <String, Color>{
    'void': voidColor,
    'surface-100': surface100,
    'surface-200': surface200,
    'surface-300': surface300,
    'ink': ink,
    'signal': signal,
    'plasma': plasma,
    'baseline': baseline,
    'ink-muted': inkMuted,
    'ink-faint': inkFaint,
    'line': line,
    'signal-ghost': signalGhost,
    'plasma-ghost': plasmaGhost,
    'go': go,
    'go-ghost': goGhost,
    'warn': warn,
    'warn-ghost': warnGhost,
    'nogo': nogo,
    'nogo-ghost': nogoGhost,
  };

  /// La couleur du jeton [name] ; une erreur de test si le jeton est inconnu.
  static Color named(String name) {
    final Color? color = byName[name];
    if (color == null) {
      throw ArgumentError(
        'jeton de couleur inconnu « $name » (connus : ${byName.keys.join(', ')})',
      );
    }
    return color;
  }

  /// Égalité à un octet d'alpha près (l'arrondi `round(alpha x 255)` du
  /// générateur de jetons) et exacte sur les canaux de couleur.
  static bool sameColor(Color a, Color b) {
    int byte(double v) => (v * 255).round();
    return byte(a.r) == byte(b.r) &&
        byte(a.g) == byte(b.g) &&
        byte(a.b) == byte(b.b) &&
        (byte(a.a) - byte(b.a)).abs() <= 1;
  }

  static String describe(Color c) {
    String hex(double v) => (v * 255).round().toRadixString(16).padLeft(2, '0');
    return '#${hex(c.r)}${hex(c.g)}${hex(c.b)}${hex(c.a)}';
  }
}
