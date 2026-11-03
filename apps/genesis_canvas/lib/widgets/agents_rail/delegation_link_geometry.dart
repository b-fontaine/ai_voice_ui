import 'dart:math' as math;
import 'dart:ui';

import 'package:shared_design_system/shared_design_system.dart'
    show SceneRadius;

/// Tracé d'une liaison de délégation (Q-85, FR-03) entre la tuile de
/// l'orchestrateur et celle d'un agent, en coordonnées de la zone de peinture.
///
/// Le trait part au-dessus de la pastille de l'orchestrateur, monte dans la
/// bande libre au-dessus des tuiles ((96 - hauteur de la tuile) / 2, plus de
/// 16 px), file à
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

  /// Diamètre du point d'état d'une tuile (`gc-agent`).
  static const double dotSize = 8;

  /// Épaisseur de la bordure d'une tuile.
  static const double tileBorder = 1;

  /// Remplissage horizontal d'une tuile (bordure non comprise).
  static const double tilePaddingX = 14;

  /// Décalage horizontal depuis le bord gauche d'une tuile : centre de son
  /// point (bordure et remplissage compris).
  static const double inset = tileBorder + tilePaddingX + dotSize / 2;

  /// Écart entre le pied du trait et le haut de la tuile.
  static const double clearance = 2;

  /// Hauteur de l'horizontale au-dessus du haut de la tuile de l'orchestrateur ;
  /// avec l'épaisseur, le trait reste dans les 16,8 px libres.
  static const double laneHeight = 11;

  /// Rayon des coins arrondis.
  static const double cornerRadius = SceneRadius.sm;

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
