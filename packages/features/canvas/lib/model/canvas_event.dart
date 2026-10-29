import 'canvas_state.dart';

/// Événements du `CanvasBloc`.
sealed class CanvasEvent {
  const CanvasEvent();
}

/// Une surface est apparue (phase squelette).
final class SurfaceAdded extends CanvasEvent {
  const SurfaceAdded(this.surfaceId);
  final String surfaceId;
}

/// Une surface a progressé vers [phase].
final class SurfacePhaseChanged extends CanvasEvent {
  const SurfacePhaseChanged(this.surfaceId, this.phase);
  final String surfaceId;
  final SurfacePhase phase;
}

/// Une surface a disparu.
final class SurfaceRemoved extends CanvasEvent {
  const SurfaceRemoved(this.surfaceId);
  final String surfaceId;
}

/// Remise à vide du canevas (toutes les surfaces sont supprimées du moteur).
final class CanvasResetRequested extends CanvasEvent {
  const CanvasResetRequested();
}

/// Un message A2UI v0.9 (forme JSON) à appliquer au moteur genui.
///
/// Le Bloc déduit les changements de surface et de phase du type du message.
final class A2uiMessageReceived extends CanvasEvent {
  const A2uiMessageReceived(this.message);
  final Map<String, dynamic> message;
}
