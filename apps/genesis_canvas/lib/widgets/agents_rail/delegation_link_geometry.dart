import 'dart:math' as math;
import 'dart:ui';

/// Tracé d'une liaison de délégation (Q-85, FR-03) entre la tuile de
/// l'orchestrateur et celle d'un agent, en coordonnées de la zone de peinture.
///
/// Le trait part au-dessus de la pastille de l'orchestrateur, monte dans la
/// bande libre au-dessus des tuiles ((96 - 2 × 24 × 1,3) / 2 = 16,8 px), file à
/// l'horizontale au-dessus des tuiles intermédiaires puis redescend au-dessus
/// de la pastille de l'agent. Aucune partie du trait ne recouvre un libellé.
///
/// Tous les liens d'un même orchestrateur partagent le début de leur tracé
/// (montée et premier coin) : leurs pointillés s'y confondent. Le chemin et
/// ses mesures sont calculés une fois par géométrie ; seule la phase des
/// pointillés change d'une image à l'autre.
final class DelegationLinkGeometry {
  DelegationLinkGeometry({required this.orchestrator, required this.target});

  /// Épaisseur du trait (élément graphique lisible, >= 3 px).
  static const double strokeWidth = 3;

  /// Diamètre de la pastille d'état d'une tuile.
  static const double dotSize = 14;

  /// Décalage horizontal depuis le bord gauche d'une tuile : centre de sa
  /// pastille.
  static const double inset = dotSize / 2;

  /// Écart entre le pied du trait et le haut de la tuile.
  static const double clearance = 2;

  /// Hauteur de l'horizontale au-dessus du haut de la tuile de l'orchestrateur ;
  /// avec l'épaisseur, le trait reste dans les 16,8 px libres.
  static const double laneHeight = 11;

  /// Rayon des coins arrondis.
  static const double cornerRadius = 6;

  /// Rectangle de la tuile de l'orchestrateur.
  final Rect orchestrator;

  /// Rectangle de la tuile de l'agent.
  final Rect target;

  /// Chemin du lien, sans pointillé, de l'orchestrateur vers l'agent.
  late final Path path = _build();

  /// Mesure du [path] (un seul contour), pour en extraire les pointillés.
  late final PathMetric metric = path.computeMetrics().single;

  /// Longueur du [path].
  double get length => metric.length;

  Path _build() {
    final double startX = orchestrator.left + inset;
    final double endX = target.left + inset;
    final double direction = endX >= startX ? 1 : -1;
    final double radius = math.min(cornerRadius, (endX - startX).abs() / 2);
    final double lane = orchestrator.top - laneHeight;
    final double startFoot = orchestrator.top - clearance;
    final double endFoot = target.top - clearance;
    return Path()
      ..moveTo(startX, startFoot)
      ..lineTo(startX, lane + radius)
      ..quadraticBezierTo(startX, lane, startX + direction * radius, lane)
      ..lineTo(endX - direction * radius, lane)
      ..quadraticBezierTo(endX, lane, endX, lane + radius)
      ..lineTo(endX, endFoot);
  }

  @override
  bool operator ==(Object other) =>
      other is DelegationLinkGeometry &&
      other.orchestrator == orchestrator &&
      other.target == target;

  @override
  int get hashCode => Object.hash(orchestrator, target);
}
