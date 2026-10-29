import 'package:feature_canvas/feature_canvas.dart' show CanvasBoard;
import 'package:flutter/widgets.dart';
import 'package:genui/genui.dart' show SurfaceController;

/// Canevas des surfaces de la page (FR-01), posé sur le `CanvasBoard` de la
/// slice `canvas`. Vide tant qu'aucune surface n'est créée.
///
/// Exige un `CanvasBloc` fourni plus haut dans l'arbre (voir la page).
class CanvasBoardView extends StatelessWidget {
  const CanvasBoardView({super.key, required this.controller});

  final SurfaceController controller;

  @override
  Widget build(BuildContext context) =>
      CanvasBoard(key: const Key('canvas-board'), controller: controller);
}
