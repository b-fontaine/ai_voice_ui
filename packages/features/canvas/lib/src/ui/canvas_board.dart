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
    builder: (BuildContext context, CanvasState state) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final String id in state.surfaceIds)
          Expanded(
            child: KeyedSubtree(
              key: ValueKey<String>('surface-$id'),
              child: state.phaseOf(id) == SurfacePhase.skeleton
                  ? DsSkeleton(key: ValueKey<String>('skeleton-$id'))
                  : Surface(surfaceContext: controller.contextFor(id)),
            ),
          ),
      ],
    ),
  );
}
