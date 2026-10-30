import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:entity_catalog/entity_catalog.dart' show GenesisContract;
import 'package:shared_backend_channel/shared_backend_channel.dart'
    show CanvasActionClient, CanvasActionResult;

import 'canvas_action_event.dart';
import 'canvas_action_settings.dart';
import 'canvas_action_state.dart';

/// Envoie au backend l'action cliquée dans une Barre d'actions et garde les
/// boutons inactifs jusqu'à la fin du travail de l'agent (pdr-0065, D6).
///
/// Cycle : [ActionRequested] → [ActionSending] (le client fait un seul essai ;
/// ce Bloc réessaie, de façon bornée, sur `busy` et `no_session`) →
/// [ActionRunning] une fois le 202 reçu → [ActionIdle] quand l'activité des
/// agents repasse à « repos » après avoir été vue au travail, à la fermeture
/// de la session, à la remise à vide ou au bout de `maxDuration`. Un refus ou
/// un échec donne [ActionFailed] puis [ActionIdle].
///
/// `ActionRequested` utilise `droppable()` : un clic reçu pendant que le cycle
/// précédent dure est ignoré. Les autres événements sont de courts signaux,
/// traités sans attendre ce cycle.
class CanvasActionBloc extends Bloc<CanvasActionEvent, CanvasActionState> {
  CanvasActionBloc({required this._client, required this._settings})
    : super(const ActionIdle()) {
    on<ActionRequested>(_onRequested, transformer: droppable());
    on<ActionActivityChanged>(_onActivity, transformer: sequential());
    on<ActionSessionClosed>(_onSessionClosed, transformer: sequential());
    on<ActionStageReset>(_onReset, transformer: sequential());
  }

  final CanvasActionClient _client;
  final CanvasActionSettings _settings;

  /// Incrémenté à chaque remise à vide et à la fermeture : un cycle dont la
  /// génération est périmée s'arrête sans rien émettre.
  int _generation = 0;

  /// Activité vue au travail pendant le cycle en cours.
  bool _sawBusy = false;

  /// Activité repassée au repos après avoir été vue au travail.
  bool _finished = false;

  /// Réveil de l'attente en cours (délai entre essais ou durée de l'action).
  Completer<void>? _wake;
  Timer? _timer;

  Future<void> _onRequested(
    ActionRequested event,
    Emitter<CanvasActionState> emit,
  ) async {
    if (!GenesisContract.actionIds.contains(event.name)) return;
    final int generation = _generation;
    emit(ActionSending(event.name));

    CanvasActionFailure? failure;
    var retriesLeft = _settings.retries;
    while (true) {
      // Remis à zéro avant chaque envoi : une fin d'activité vue pendant un
      // `busy` (délégation vocale) ne doit pas compter pour cette action.
      // Si le tag d'action disparaît après le 202, le backend publie un plan
      // sans agent ni activité : les boutons restent inactifs jusqu'à
      // `maxDuration`.
      _sawBusy = false;
      _finished = false;
      final CanvasActionResult result = await _client.send(
        action: event.name,
        surface: event.surfaceId,
      );
      if (generation != _generation) return;
      switch (result) {
        case CanvasActionResult.accepted:
          failure = null;
        case CanvasActionResult.busy || CanvasActionResult.noSession:
          failure = result == CanvasActionResult.busy
              ? CanvasActionFailure.busy
              : CanvasActionFailure.noSession;
          if (retriesLeft > 0) {
            retriesLeft--;
            await _sleep(_settings.retryInterval);
            if (generation != _generation) return;
            continue;
          }
        case CanvasActionResult.rejected:
          failure = CanvasActionFailure.rejected;
        case CanvasActionResult.failed:
          failure = CanvasActionFailure.unreachable;
      }
      break;
    }

    if (failure != null) {
      emit(ActionFailed(failure));
      emit(const ActionIdle());
      return;
    }
    emit(ActionRunning(event.name));
    if (!_finished) await _sleep(_settings.maxDuration);
    if (generation != _generation) return;
    emit(const ActionIdle());
  }

  void _onActivity(
    ActionActivityChanged event,
    Emitter<CanvasActionState> emit,
  ) {
    if (state is ActionIdle || state is ActionFailed) return;
    if (event.busy) {
      _sawBusy = true;
    } else if (_sawBusy) {
      _finished = true;
      if (state is ActionRunning) _wakeUp();
    }
  }

  void _onSessionClosed(
    ActionSessionClosed event,
    Emitter<CanvasActionState> emit,
  ) {
    if (state is ActionRunning) {
      _finished = true;
      _wakeUp();
    }
  }

  void _onReset(ActionStageReset event, Emitter<CanvasActionState> emit) {
    _abandon();
    if (state is! ActionIdle) emit(const ActionIdle());
  }

  /// Attend [duration] ; [_wakeUp] ou [_abandon] interrompent l'attente.
  Future<void> _sleep(Duration duration) {
    final Completer<void> wake = Completer<void>();
    _wake = wake;
    _timer = Timer(duration, () {
      if (!wake.isCompleted) wake.complete();
    });
    return wake.future.whenComplete(() {
      _timer?.cancel();
      _timer = null;
      if (identical(_wake, wake)) _wake = null;
    });
  }

  void _wakeUp() {
    final Completer<void>? wake = _wake;
    if (wake != null && !wake.isCompleted) wake.complete();
  }

  /// Périme le cycle en cours et le réveille pour qu'il se termine.
  void _abandon() {
    _generation++;
    _wakeUp();
  }

  @override
  Future<void> close() {
    _abandon();
    return super.close();
  }
}
