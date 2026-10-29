import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:genui/genui.dart' show Surface, SurfaceController;

import '../model/canvas_bloc.dart';
import '../model/canvas_state.dart';

/// Grille des surfaces actives (FR-01). Vide tant qu'aucune surface n'existe.
///
/// La disposition est tenue par l'app, pas par l'IA (pdr-0015). Le
/// [controller] est celui que le `CanvasBloc` alimente ; il est injecté.
class CanvasBoard extends StatelessWidget {
  const CanvasBoard({super.key, required this.controller});

  final SurfaceController controller;

  @override
  Widget build(BuildContext context) => BlocBuilder<CanvasBloc, CanvasState>(
    buildWhen: (CanvasState previous, CanvasState next) =>
        !listEquals(previous.surfaceIds, next.surfaceIds),
    builder: (BuildContext context, CanvasState state) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final String id in state.surfaceIds)
          Expanded(
            child: Surface(
              key: ValueKey<String>('surface-$id'),
              surfaceContext: controller.contextFor(id),
            ),
          ),
      ],
    ),
  );
}
