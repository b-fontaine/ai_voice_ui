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
/// arrive (A1). Toutes les cellules ont le même parent : le `State` des
/// moteurs de rendu survit aussi au passage de 2 × 2 à 3 × 2 (A7).
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
  static const double actionsBandHeight = 72;

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
      //
      // Parent unique (A7, 012) : toutes les cellules sont des enfants
      // directs d'un même `CustomMultiChildLayout`, repérés par leur clé. Un
      // `Column` de `Row` recréerait les `State` des moteurs de rendu au
      // passage de 2 × 2 à 3 × 2 (une cellule change de parent). Le
      // `CustomMultiChildLayout` plutôt qu'un `Stack` + `Positioned` : la
      // géométrie (colonnes, rangées, bandeau) est calculée en un seul
      // endroit, le délégué, sans recalcul dans `build`.
      final bool hasBand = state.surfaceIds.isNotEmpty;
      return CustomMultiChildLayout(
        delegate: _BoardLayoutDelegate(
          slots: ids,
          columns: columns,
          bandId: hasBand ? _bandSurface : null,
        ),
        children: <Widget>[
          for (final String id in ids)
            LayoutId(
              key: ValueKey<String>('slot-$id'),
              id: id,
              child: _cell(context, id, state),
            ),
          if (hasBand)
            LayoutId(
              key: ValueKey<String>('slot-$_bandSurface'),
              id: _bandSurface,
              child: state.surfaceIds.contains(_bandSurface)
                  ? _cell(context, _bandSurface, state)
                  : const SizedBox.shrink(),
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

/// Géométrie de la grille : [slots] dans l'ordre de lecture sur [columns]
/// colonnes de largeur égale, rangées de hauteur égale, puis le bandeau de
/// [CanvasBoard.actionsBandHeight] sur toute la largeur s'il existe.
class _BoardLayoutDelegate extends MultiChildLayoutDelegate {
  _BoardLayoutDelegate({
    required this.slots,
    required this.columns,
    required this.bandId,
  });

  final List<String> slots;
  final int columns;

  /// Identifiant du bandeau ; `null` : pas de bandeau (aucune surface).
  final String? bandId;

  @override
  void performLayout(Size size) {
    final double bandHeight = bandId != null
        ? CanvasBoard.actionsBandHeight.clamp(0, size.height)
        : 0;
    final double gridHeight = size.height - bandHeight;
    final int rows = slots.isEmpty
        ? 1
        : (slots.length + columns - 1) ~/ columns;
    final double cellWidth = size.width / columns;
    final double cellHeight = gridHeight / rows;
    for (int i = 0; i < slots.length; i++) {
      final Offset origin = Offset(
        (i % columns) * cellWidth,
        (i ~/ columns) * cellHeight,
      );
      layoutChild(slots[i], BoxConstraints.tight(Size(cellWidth, cellHeight)));
      positionChild(slots[i], origin);
    }
    final String? band = bandId;
    if (band != null && hasChild(band)) {
      layoutChild(band, BoxConstraints.tight(Size(size.width, bandHeight)));
      positionChild(band, Offset(0, gridHeight));
    }
  }

  @override
  bool shouldRelayout(_BoardLayoutDelegate oldDelegate) =>
      columns != oldDelegate.columns ||
      bandId != oldDelegate.bandId ||
      !listEquals(slots, oldDelegate.slots);
}
