import 'dart:async';

import 'package:entity_session/entity_session.dart'
    show A2uiEnvelopeReceived, JournalEntry;
import 'package:meta/meta.dart' show immutable;

import 'replay_settings.dart';

/// État de lecture du lecteur. `paused` couvre aussi l'état initial.
enum ReplayStatus { playing, paused, ended }

/// Photographie du lecteur, émise à chaque changement.
@immutable
class ReplaySnapshot {
  const ReplaySnapshot({
    required this.position,
    required this.duration,
    required this.speed,
    required this.status,
  });

  final Duration position;
  final Duration duration;
  final double speed;
  final ReplayStatus status;

  @override
  bool operator ==(Object other) =>
      other is ReplaySnapshot &&
      other.position == position &&
      other.duration == duration &&
      other.speed == speed &&
      other.status == status;

  @override
  int get hashCode => Object.hash(position, duration, speed, status);

  @override
  String toString() =>
      'ReplaySnapshot($position/$duration, ${speed}x, ${status.name})';
}

/// Lecteur de rejeu à horloge virtuelle.
///
/// La position vit sur un axe comprimé : l'écart entre deux entrées
/// consécutives est plafonné à `maxGap` (valeur à 1x). Un seul
/// `Timer.periodic` est actif à la fois ; à chaque pas la position avance de
/// `tick x vitesse` et toutes les entrées dont la position est atteinte sont
/// injectées dans l'ordre. Aucune heure murale n'est lue.
///
/// Les entrées à la position 0 sont injectées dès l'appel à [play] (ou au
/// retour d'un [seek] à 0 en lecture), sans attendre le premier pas.
class ReplayPlayer {
  ReplayPlayer({
    required List<JournalEntry> entries,
    required ReplaySettings settings,
    required this._inject,
    required this._clearStage,
  }) : _entries = List<JournalEntry>.unmodifiable(entries),
       _settings = settings,
       _speed = settings.defaultSpeed {
    Duration at = Duration.zero;
    _positions = <Duration>[];
    for (int i = 0; i < _entries.length; i++) {
      if (i > 0) {
        final Duration gap = Duration(
          milliseconds: _entries[i].tMs - _entries[i - 1].tMs,
        );
        at += gap > settings.maxGap ? settings.maxGap : gap;
      }
      _positions.add(at);
    }
    _duration = at;
    _current = _build();
  }

  final List<JournalEntry> _entries;
  final ReplaySettings _settings;
  final void Function(A2uiEnvelopeReceived event) _inject;
  final void Function() _clearStage;
  late final List<Duration> _positions;
  late final Duration _duration;

  final StreamController<ReplaySnapshot> _controller =
      StreamController<ReplaySnapshot>.broadcast();

  Duration _position = Duration.zero;
  double _speed;
  int _cursor = 0;
  bool _wantPlaying = false;
  bool _ended = false;
  bool _disposed = false;
  Timer? _ticker;
  Timer? _barrier;
  late ReplaySnapshot _current;

  /// Dernière photographie.
  ReplaySnapshot get snapshot => _current;

  /// Flux broadcast des changements d'état.
  Stream<ReplaySnapshot> get snapshots => _controller.stream;

  ReplayStatus get _status => _ended
      ? ReplayStatus.ended
      : (_wantPlaying ? ReplayStatus.playing : ReplayStatus.paused);

  ReplaySnapshot _build() => ReplaySnapshot(
    position: _position,
    duration: _duration,
    speed: _speed,
    status: _status,
  );

  void _publish() {
    _current = _build();
    if (!_controller.isClosed) _controller.add(_current);
  }

  /// Lance ou reprend la lecture. Après la fin, recommence depuis le début.
  void play() {
    if (_disposed) return;
    if (_ended) {
      restart();
      return;
    }
    if (_wantPlaying) return;
    _wantPlaying = true;
    if (_barrier == null) _resumeFromHere();
    _publish();
  }

  /// Suspend la lecture ; la position est conservée.
  void pause() {
    if (_disposed || !_wantPlaying) return;
    _wantPlaying = false;
    _ticker?.cancel();
    _ticker = null;
    _publish();
  }

  /// Revient à la position 0 (scène vidée), garde la vitesse et lit.
  void restart() {
    if (_disposed) return;
    _wantPlaying = true;
    seek(Duration.zero);
  }

  /// Change la vitesse ; la position continue sans saut.
  void setSpeed(double speed) {
    if (speed <= 0) throw ArgumentError.value(speed, 'speed', 'doit être > 0');
    if (_disposed || speed == _speed) return;
    _speed = speed;
    _publish();
  }

  /// Se place à [target] : vide la scène, attend un tour de boucle (les
  /// remises à vide des Blocs sont synchrones et doivent précéder les
  /// messages), puis réinjecte d'un coup toutes les entrées jusqu'à la
  /// position. La lecture reprend si elle était en cours. Un nouveau seek
  /// annule le précédent.
  void seek(Duration target) {
    if (_disposed) return;
    _ticker?.cancel();
    _ticker = null;
    _barrier?.cancel();
    _ended = false;
    _position = target < Duration.zero
        ? Duration.zero
        : (target > _duration ? _duration : target);
    _cursor = _entries.length; // rien n'est émis avant la fin de la barrière
    _clearStage();
    _barrier = Timer(Duration.zero, _afterBarrier);
    _publish();
  }

  void _afterBarrier() {
    _barrier = null;
    if (_disposed) return;
    _cursor = 0;
    _emitDue();
    if (_position >= _duration && !_wantPlaying) {
      _ended = true;
    }
    if (_wantPlaying) _resumeFromHere();
    _publish();
  }

  /// Arrête toute lecture, sans libérer le lecteur.
  void stop() {
    if (_disposed) return;
    _cancelTimers();
    final bool changed = _wantPlaying;
    _wantPlaying = false;
    if (changed) _publish();
  }

  /// Libère le lecteur, de façon synchrone : plus aucun minuteur ni injection.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _cancelTimers();
    _controller.close();
  }

  void _cancelTimers() {
    _ticker?.cancel();
    _ticker = null;
    _barrier?.cancel();
    _barrier = null;
  }

  void _resumeFromHere() {
    _emitDue();
    if (_position >= _duration) {
      _finish();
      return;
    }
    _ticker ??= Timer.periodic(_settings.tick, (_) => _step());
  }

  void _step() {
    final Duration delta = Duration(
      microseconds: (_settings.tick.inMicroseconds * _speed).round(),
    );
    final Duration next = _position + delta;
    _position = next > _duration ? _duration : next;
    _emitDue();
    if (_position >= _duration) _finish();
    _publish();
  }

  void _finish() {
    _ticker?.cancel();
    _ticker = null;
    _wantPlaying = false;
    _ended = true;
  }

  void _emitDue() {
    while (_cursor < _entries.length && _positions[_cursor] <= _position) {
      final JournalEntry e = _entries[_cursor++];
      _inject(
        A2uiEnvelopeReceived(
          message: e.message,
          raw: e.raw,
          agent: e.agent,
          task: e.task,
        ),
      );
      if (_disposed) return;
    }
  }
}
