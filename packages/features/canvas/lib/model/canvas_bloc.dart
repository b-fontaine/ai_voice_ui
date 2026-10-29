import 'package:a2ui_core/a2ui_core.dart' as a2ui;
import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:genui/genui.dart' show SurfaceController;

import 'canvas_event.dart';
import 'canvas_state.dart';

/// Tient la liste ordonnée des surfaces et leur phase, et applique les messages
/// A2UI au [SurfaceController] injecté.
///
/// Le moteur genui reste hors de l'état : le Bloc n'expose que des `surfaceId`
/// et des phases. Les events sont traités dans l'ordre d'arrivée (`sequential`) :
/// un `updateComponents` ne doit jamais dépasser son `createSurface`.
class CanvasBloc extends Bloc<CanvasEvent, CanvasState> {
  CanvasBloc(this._controller) : super(const CanvasState.empty()) {
    // Un seul handler `sequential` pour tous les types d'events : le
    // transformer s'applique par `on<E>`, donc des handlers distincts
    // s'exécuteraient en concurrence et l'ordre entre types serait perdu.
    on<CanvasEvent>(_onEvent, transformer: sequential());
  }

  final SurfaceController _controller;

  void _onEvent(CanvasEvent event, Emitter<CanvasState> emit) {
    switch (event) {
      case SurfaceAdded(:final surfaceId):
        emit(state.withSurface(surfaceId));
      case SurfacePhaseChanged(:final surfaceId, :final phase):
        emit(state.withPhase(surfaceId, phase));
      case SurfaceRemoved(:final surfaceId):
        emit(state.withoutSurface(surfaceId));
      case CanvasResetRequested():
        _onReset(emit);
      case A2uiMessageReceived():
        _onMessage(event, emit);
    }
  }

  void _onMessage(A2uiMessageReceived event, Emitter<CanvasState> emit) {
    final a2ui.A2uiMessage message = a2ui.A2uiMessage.fromJson(event.message);
    _controller.handleMessage(message);
    emit(switch (message) {
      a2ui.CreateSurfaceMessage(:final surfaceId) => state.withSurface(
        surfaceId,
      ),
      a2ui.UpdateComponentsMessage(:final surfaceId) => state.withPhase(
        surfaceId,
        SurfacePhase.components,
      ),
      a2ui.UpdateDataModelMessage(:final surfaceId) => state.withPhase(
        surfaceId,
        SurfacePhase.data,
      ),
      a2ui.DeleteSurfaceMessage(:final surfaceId) => state.withoutSurface(
        surfaceId,
      ),
      _ => state,
    });
  }

  void _onReset(Emitter<CanvasState> emit) {
    for (final String id in _controller.activeSurfaceIds.toList()) {
      _controller.handleMessage(a2ui.DeleteSurfaceMessage(surfaceId: id));
    }
    emit(const CanvasState.empty());
  }
}
