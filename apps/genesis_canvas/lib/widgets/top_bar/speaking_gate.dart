import 'package:flutter/foundation.dart';

/// Vrai tant que l'IA parle, avec une hystérésis : le niveau lissé de l'orbe
/// oscille autour du seuil de parole, et les anneaux ou l'onde ne doivent pas
/// clignoter à chaque franchissement.
///
/// On entre en parole au-dessus de `threshold` ; on n'en sort qu'en dessous de
/// `threshold * releaseRatio`. La porte ne pilote que la visibilité du
/// mouvement : les boucles d'animation tournent en continu et ne sont jamais
/// relancées (plan 019, P2).
class SpeakingGate extends ValueNotifier<bool> {
  SpeakingGate({
    required ValueListenable<double> level,
    required this.threshold,
    this.releaseRatio = 0.5,
  }) : _level = level,
       super(level.value > threshold) {
    level.addListener(_sync);
  }

  final ValueListenable<double> _level;

  /// Niveau au-dessus duquel l'IA est en parole.
  final double threshold;

  /// Part du seuil sous laquelle l'IA est considérée de nouveau silencieuse.
  final double releaseRatio;

  void _sync() {
    final double current = _level.value;
    value = value ? current > threshold * releaseRatio : current > threshold;
  }

  @override
  void dispose() {
    _level.removeListener(_sync);
    super.dispose();
  }
}
