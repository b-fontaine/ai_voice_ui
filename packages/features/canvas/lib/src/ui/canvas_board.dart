import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:genui/genui.dart' show Surface, SurfaceController;
import 'package:shared_design_system/shared_design_system.dart' show DsSkeleton;

import '../model/canvas_bloc.dart';
import '../model/canvas_state.dart';

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
class CanvasBoard extends StatelessWidget {
  const CanvasBoard({super.key, required this.controller});

  final SurfaceController controller;

  @override
  Widget build(BuildContext context) => BlocBuilder<CanvasBloc, CanvasState>(
    buildWhen: (CanvasState previous, CanvasState next) =>
        !listEquals(previous.surfaceIds, next.surfaceIds) ||
        next.surfaceIds.any(
          (String id) => previous.phaseOf(id) != next.phaseOf(id),
        ),
    builder: (BuildContext context, CanvasState state) {
      final List<String> ids = state.surfaceIds;
      final int columns = _columnsFor(ids.length);
      return Column(
        children: <Widget>[
          for (int start = 0; start < ids.length; start += columns)
            Expanded(
              child: Row(
                children: <Widget>[
                  for (int i = start; i < start + columns; i++)
                    Expanded(
                      child: i < ids.length
                          ? _cell(ids[i], state)
                          : const SizedBox.shrink(),
                    ),
                ],
              ),
            ),
        ],
      );
    },
  );

  /// Grille tenue par l'app (pdr-0015) : une colonne pour une surface, 2 × 2
  /// jusqu'à quatre, 3 × 2 pour cinq ou six (A7a du plan 007). L'ordre est
  /// celui d'arrivée ; l'emplacement par surface (kpi, trend, reviews,
  /// checklist) viendra avec la grille de la page.
  static int _columnsFor(int count) => switch (count) {
    <= 1 => 1,
    <= 4 => 2,
    _ => 3,
  };

  Widget _cell(String id, CanvasState state) => KeyedSubtree(
    key: ValueKey<String>('surface-$id'),
    child: state.phaseOf(id) == SurfacePhase.skeleton
        ? DsSkeleton(key: ValueKey<String>('skeleton-$id'))
        : Surface(surfaceContext: controller.contextFor(id)),
  );
}
