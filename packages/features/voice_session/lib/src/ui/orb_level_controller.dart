import 'dart:async';

import 'package:entity_session/entity_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../model/orb_smoother.dart';

/// Niveau lissé de l'orbe, publié à chaque frame hors de tout état Bloc.
///
/// Les [OrbLevelChanged] fixent la cible ; un [Ticker] lisse la valeur vers
/// cette cible et s'arrête au repos (niveau et cible à 0). Sans nouvel
/// événement pendant `silenceTimeout` (temps du ticker, pas de `Timer`), la
/// cible retombe à 0. La fin de session ([SessionStateChanged] `closed`,
/// [ChannelLost]) remet tout à 0 immédiatement.
class OrbLevelController {
  OrbLevelController({
    required TickerProvider vsync,
    required Stream<SessionEvent> events,
    this._smoother = const OrbSmoother(),
    this._silenceTimeout = const Duration(milliseconds: 600),
  }) {
    _ticker = vsync.createTicker(_onTick);
    _subscription = events.listen(_onEvent, onError: _onError);
  }

  final OrbSmoother _smoother;
  final Duration _silenceTimeout;
  final ValueNotifier<double> _level = ValueNotifier<double>(0);

  late final Ticker _ticker;
  late final StreamSubscription<SessionEvent> _subscription;

  double _target = 0;
  Duration _lastElapsed = Duration.zero;
  Duration _sinceEvent = Duration.zero;
  bool _disposed = false;

  /// Niveau lissé, dans 0..1.
  ValueListenable<double> get level => _level;

  void _onEvent(SessionEvent event) {
    if (_disposed) return;
    switch (event) {
      case OrbLevelChanged(:final double level):
        if (level.isNaN) return;
        _target = level.clamp(0.0, 1.0);
        _sinceEvent = Duration.zero;
        if ((_target > 0 || _level.value > 0) && !_ticker.isActive) {
          _lastElapsed = Duration.zero;
          _ticker.start();
        }
      case SessionStateChanged(state: SessionState.closed):
      case ChannelLost():
        _reset();
      case _:
        break;
    }
  }

  // Le flux de la source n'émet jamais d'erreur ; on ne plante pas si besoin.
  void _onError(Object error, StackTrace stackTrace) {}

  void _reset() {
    _target = 0;
    if (_ticker.isActive) _ticker.stop();
    _level.value = 0;
  }

  void _onTick(Duration elapsed) {
    final Duration dt = elapsed - _lastElapsed;
    _lastElapsed = elapsed;
    _sinceEvent += dt;
    if (_sinceEvent >= _silenceTimeout) _target = 0;
    _level.value = _smoother.step(_level.value, _target, dt);
    if (_target == 0 && _level.value == 0) _ticker.stop();
  }

  /// Annule l'abonnement et le ticker, libère le notifier. Idempotent.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_subscription.cancel());
    _ticker.dispose();
    _level.dispose();
  }
}
