/// Largeur du contenu des trois colonnes ajustables de la checklist
/// (remplissage exclu).
typedef ColumnWidths = ({double label, double threshold, double value});

/// Nombre de partages essayés entre la colonne du critère et celle de la
/// valeur quand la cellule est étroite.
const int defaultSplitSteps = 32;

/// Partage de la largeur [available] entre les colonnes du tableau (fonction
/// pure : toute mesure passe par [minimums] et [rowsHeight]).
///
/// Les colonnes du seuil et de la puce ([chip]) gardent leur largeur
/// naturelle ([natural]) ; quand [available] est trop étroit, le critère et la
/// valeur rétrécissent, jamais en dessous du mot le plus long ([minimums],
/// demandé seulement si la ligne ne tient pas). Quand il est large, le critère
/// prend le surplus. Un [available] infini laisse les largeurs naturelles.
///
/// Entre les minimums, [steps] + 1 partages sont essayés : [rowsHeight] donne
/// la hauteur de toutes les lignes pour un partage ; on garde celui qui donne
/// les lignes les moins hautes (à égalité, le plus proche du partage
/// proportionnel). Si même les minimums ne tiennent pas, tout rétrécit
/// proportionnellement.
ColumnWidths splitColumns({
  required double available,
  required ColumnWidths natural,
  required double chip,
  required ({double label, double value}) Function() minimums,
  required double Function(double label, double value) rowsHeight,
  int steps = defaultSplitSteps,
}) {
  double label = natural.label;
  double threshold = natural.threshold;
  double value = natural.value;
  final double total = label + threshold + value + chip;

  if (!available.isFinite || total <= available) {
    if (available.isFinite) label += available - total;
    return (label: label, threshold: threshold, value: value);
  }

  // Trop étroit : le critère et la valeur se partagent ce que laissent le
  // seuil et la puce.
  final double shared = available - threshold - chip;
  final ({double label, double value}) min = minimums();
  if (shared >= min.label + min.value) {
    final double proportional = shared * label / (label + value);
    final double span = shared - min.value - min.label;
    double bestLabel = min.label;
    double bestScore = double.infinity;
    for (int step = 0; step <= steps; step++) {
      final double candidate = min.label + span * step / steps;
      final double score =
          rowsHeight(candidate, shared - candidate) +
          (candidate - proportional).abs() / 1000;
      if (score < bestScore) {
        bestScore = score;
        bestLabel = candidate;
      }
    }
    return (label: bestLabel, threshold: threshold, value: shared - bestLabel);
  }

  // Même au plus serré les mots ne tiennent pas : tout rétrécit
  // proportionnellement (un mot peut alors être coupé, jamais perdu).
  final double flexible = available - chip;
  final double k = flexible > 0 ? flexible / (label + threshold + value) : 0;
  return (label: label * k, threshold: threshold * k, value: value * k);
}
