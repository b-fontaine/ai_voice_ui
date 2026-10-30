import 'package:entity_catalog/entity_catalog.dart' show GenesisContract;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:genui/genui.dart' show Surface, SurfaceController;
import 'package:shared_design_system/shared_design_system.dart'
    show DsSkeleton, SceneTheme;

import '../model/canvas_bloc.dart';
import '../model/canvas_state.dart';
import 'dashed_outline_painter.dart';

/// Grille des surfaces actives (FR-01). Vide tant qu'aucune surface n'existe.
///
/// La disposition est tenue par l'app, pas par l'IA (pdr-0015). Le
/// [controller] est celui que le `CanvasBloc` alimente ; il est injecté.
///
/// Chaque surface a sa cellule `surface-<id>` dès `createSurface`. Le board
/// peint lui-même le squelette tant que la phase est `skeleton` : avec genui
/// 0.10.4 le `defaultBuilder` de `Surface` ne s'affiche jamais après
/// `createSurface` (la définition existe, sans `root`). `Surface` n'est montée
/// qu'à partir de `updateComponents`.
///
/// La Barre d'actions est un **bandeau** sous la grille, de largeur égale et
/// de hauteur [actionsBandHeight], réservée dès la première surface : la grille
/// 2 × 2 et le `State` de ses quatre cellules ne changent pas quand `actions`
/// arrive (A1).
///
/// Emplacement **déterministe** (A7a) : les surfaces du contrat à leur rang
/// (kpi, trend, reviews, checklist), puis les surfaces inconnues dans leur
/// ordre d'arrivée. Pas de défilement, pas de mise à l'échelle.
class CanvasBoard extends StatelessWidget {
  const CanvasBoard({
    super.key,
    required this.controller,
    this.highlightedSurfaceId,
  });

  /// Hauteur réservée au bandeau de la Barre d'actions.
  static const double actionsBandHeight = 80;

  final SurfaceController controller;

  /// Surface du message en cours du panneau du protocole (D2) : elle reçoit un
  /// contour pointillé `highlight-<id>` si elle est présente dans le canevas
  /// (un message refusé n'a pas de surface, donc pas de contour).
  final String? highlightedSurfaceId;

  @override
  Widget build(BuildContext context) => BlocBuilder<CanvasBloc, CanvasState>(
    buildWhen: (CanvasState previous, CanvasState next) =>
        !listEquals(previous.surfaceIds, next.surfaceIds) ||
        next.surfaceIds.any(
          (String id) => previous.phaseOf(id) != next.phaseOf(id),
        ),
    builder: (BuildContext context, CanvasState state) {
      final List<String> ids = _inSlotOrder(state.surfaceIds);
      final int columns = _columnsFor(ids.length);
      // Le bandeau est réservé dès la première surface : les cellules de la
      // grille ne bougent pas quand `actions` arrive (A1, S-02).
      return Column(
        children: <Widget>[
          Expanded(
            child: Column(
              children: <Widget>[
                for (int start = 0; start < ids.length; start += columns)
                  Expanded(
                    child: Row(
                      children: <Widget>[
                        for (int i = start; i < start + columns; i++)
                          Expanded(
                            child: i < ids.length
                                ? _cell(context, ids[i], state)
                                : const SizedBox.shrink(),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (state.surfaceIds.isNotEmpty)
            SizedBox(
              height: actionsBandHeight,
              child: state.surfaceIds.contains(_bandSurface)
                  ? _cell(context, _bandSurface, state)
                  : null,
            ),
        ],
      );
    },
  );

  /// Rang d'emplacement des surfaces du contrat, dans l'ordre des composants.
  static final List<String> _contractOrder = <String>[
    for (final String component in GenesisContract.components)
      ?GenesisContract.surfaceOf(component),
  ];

  /// Surface du bandeau (Barre d'actions), hors de la grille (A1, pdr-0065 D7).
  static final String _bandSurface = GenesisContract.surfaceOf('ActionBar')!;

  /// Surfaces de la grille : celles du contrat dans l'ordre du contrat, puis
  /// les autres dans leur ordre d'arrivée ; le bandeau n'en fait pas partie.
  static List<String> _inSlotOrder(List<String> arrival) => <String>[
    for (final String id in _contractOrder)
      if (id != _bandSurface && arrival.contains(id)) id,
    for (final String id in arrival)
      if (id != _bandSurface && !_contractOrder.contains(id)) id,
  ];

  /// Grille tenue par l'app (pdr-0015) : une colonne pour une surface, 2 × 2
  /// jusqu'à quatre, 3 × 2 pour cinq ou six (A7a du plan 007).
  static int _columnsFor(int count) => switch (count) {
    <= 1 => 1,
    <= 4 => 2,
    _ => 3,
  };

  Widget _cell(BuildContext context, String id, CanvasState state) {
    final Widget content = state.phaseOf(id) == SurfacePhase.skeleton
        ? DsSkeleton(key: ValueKey<String>('skeleton-$id'))
        : Surface(surfaceContext: controller.contextFor(id));
    return KeyedSubtree(
      key: ValueKey<String>('surface-$id'),
      // Le contenu reste le premier enfant de la pile : poser ou retirer le
      // contour ne remonte pas le moteur.
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          content,
          if (id == highlightedSurfaceId)
            IgnorePointer(
              child: CustomPaint(
                key: ValueKey<String>('highlight-$id'),
                painter: DashedOutlinePainter(
                  color: SceneTheme.of(context).highlightOutline,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
