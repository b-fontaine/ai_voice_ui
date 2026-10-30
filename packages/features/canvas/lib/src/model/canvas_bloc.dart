import 'package:a2ui_core/a2ui_core.dart' as a2ui;
import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:entity_catalog/entity_catalog.dart' show GenesisContract;
import 'package:genui/genui.dart' show DataPath, SurfaceController;

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
    // Un seul handler `sequential` pour toutes les commandes : le transformer
    // s'applique par `on<E>`, donc des handlers distincts s'exécuteraient en
    // concurrence et l'ordre entre types serait perdu.
    on<CanvasCommand>(_onCommand, transformer: sequential());
    // Une nouvelle source remplace la précédente (annulation de l'abonnement).
    on<CanvasSourceSubscribed>(_onSourceSubscribed, transformer: restartable());
  }

  final SurfaceController _controller;

  void _onCommand(CanvasCommand event, Emitter<CanvasState> emit) {
    switch (event) {
      case CanvasResetRequested():
        _onReset(emit);
      case A2uiMessageReceived():
        _onMessage(event, emit);
    }
  }

  Future<void> _onSourceSubscribed(
    CanvasSourceSubscribed event,
    Emitter<CanvasState> emit,
  ) async {
    emit(state.withSource(CanvasSourceStatus.playing));
    var failed = false;
    void fail(Object error) {
      if (failed) return;
      failed = true;
      emit(state.withSource(CanvasSourceStatus.failed, error: '$error'));
    }

    await emit.onEach<a2ui.A2uiMessage>(
      event.messages,
      onData: (message) {
        if (failed) return;
        try {
          _onMessage(A2uiMessageReceived(message), emit);
        } on Object catch (error) {
          fail(error);
        }
      },
      onError: (Object error, StackTrace _) => fail(error),
    );
    if (!emit.isDone && !failed) {
      emit(state.withSource(CanvasSourceStatus.completed));
    }
  }

  void _onMessage(A2uiMessageReceived event, Emitter<CanvasState> emit) {
    final a2ui.A2uiMessage message = event.message;
    _controller.handleMessage(message);
    final CanvasState next = switch (message) {
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
    };
    emit(switch (message) {
      a2ui.UpdateDataModelMessage(:final surfaceId)
          when surfaceId == _checklistSurface =>
        next.withDecisionStatus(_readDecisionStatus()),
      a2ui.DeleteSurfaceMessage(:final surfaceId)
          when surfaceId == _checklistSurface =>
        next.withDecisionStatus(null),
      _ => next,
    });
  }

  static final String _checklistSurface = GenesisContract.surfaceOf(
    'ReleaseChecklist',
  )!;

  /// `decisionStatus` de la checklist dans le data model, ou `null` s'il est
  /// absent ou n'est pas une chaîne.
  String? _readDecisionStatus() {
    try {
      final Object? checklist = _controller
          .contextFor(_checklistSurface)
          .dataModel
          .getValue<Object?>(DataPath('/$_checklistSurface'));
      final Object? status = checklist is Map
          ? checklist['decisionStatus']
          : null;
      return status is String ? status : null;
    } on StateError {
      return null;
    }
  }

  void _onReset(Emitter<CanvasState> emit) {
    for (final String id in _controller.activeSurfaceIds.toList()) {
      _controller.handleMessage(a2ui.DeleteSurfaceMessage(surfaceId: id));
    }
    emit(const CanvasState.empty());
  }
}
