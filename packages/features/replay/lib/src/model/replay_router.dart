import 'dart:async';

import 'package:entity_session/entity_session.dart'
    show A2uiEnvelopeReceived, A2uiJournal, JournalEntry, SessionEvent;

/// Mode d'acheminement du [ReplayRouter].
enum ReplayRouterMode { live, replay }

/// Aiguille le flux de `SessionEvent` vers l'`A2uiGate`.
///
/// Un seul flux ([events]) entre dans le gate, en direct comme en rejeu :
/// - mode `live` : chaque enveloppe A2UI vivante est enregistrée dans le
///   journal puis transmise ; les autres événements (niveaux d'orbe,
///   transcription…) ne sont ni transmis ni enregistrés ;
/// - mode `replay` : les enveloppes A2UI vivantes sont jetées et comptées ;
///   seul le lecteur alimente le flux, par [inject].
///
/// La sortie est synchrone (`sync: true`) : aucun message vivant n'est « en
/// transit » au passage en rejeu, la décision de mode se prend dans l'ordre
/// du flux. Le routeur ne ferme jamais [events] à la fin du flux vivant
/// (voir [liveDone]). Le journal n'est jamais écrit ailleurs qu'en mémoire.
class ReplayRouter {
  ReplayRouter({
    required Stream<SessionEvent> live,
    required this._journal,
    required this._nowMs,
  }) {
    _subscription = live.listen(
      _onLive,
      onError: _output.addError,
      onDone: () {
        if (!_liveDone.isCompleted) _liveDone.complete();
      },
    );
  }

  final A2uiJournal _journal;
  final int Function() _nowMs;
  final StreamController<SessionEvent> _output = StreamController<SessionEvent>(
    sync: true,
  );
  final StreamController<int> _sizes = StreamController<int>.broadcast();
  final StreamController<int> _full = StreamController<int>.broadcast();
  final Completer<void> _liveDone = Completer<void>();
  late final StreamSubscription<SessionEvent> _subscription;

  ReplayRouterMode _mode = ReplayRouterMode.live;
  int _discarded = 0;
  bool _disposed = false;
  bool _fullSignaled = false;

  /// Flux unique vers le gate (abonné une seule fois).
  Stream<SessionEvent> get events => _output.stream;

  /// Taille du journal, à chaque ajout ou vidage.
  Stream<int> get journalSize => _sizes.stream;

  /// Un seul événement, au premier ajout refusé parce que le journal est
  /// plein : le nombre d'entrées conservées (jamais leur contenu). Se réarme
  /// par [clearJournal].
  Stream<int> get journalFull => _full.stream;

  /// Au moins un `createSurface` enregistré : un rejeu a un sens.
  bool get hasPlayableJournal => _journal.hasCreateSurface;

  ReplayRouterMode get mode => _mode;

  /// Messages vivants écartés depuis l'entrée en rejeu.
  int get discardedLiveCount => _discarded;

  /// Se complète à la fin du flux vivant, sans fermer [events].
  Future<void> get liveDone => _liveDone.future;

  void _onLive(SessionEvent event) {
    if (_disposed || event is! A2uiEnvelopeReceived) return;
    if (_mode == ReplayRouterMode.replay) {
      _discarded++;
      return;
    }
    final int before = _journal.length;
    _journal.append(event, _nowMs());
    if (_journal.length != before) {
      _emitSize();
    } else if (!_fullSignaled && !_full.isClosed) {
      _fullSignaled = true;
      _full.add(_journal.length);
    }
    _output.add(event);
  }

  /// Passe en rejeu et renvoie, en un seul appel synchrone, la copie figée
  /// non modifiable des entrées du journal.
  List<JournalEntry> enterReplay() {
    _mode = ReplayRouterMode.replay;
    return List<JournalEntry>.unmodifiable(_journal.entries);
  }

  /// Revient en direct et remet à zéro le compteur de messages écartés. Le
  /// journal n'est pas touché : seule la page appelle [clearJournal].
  void exitReplay() {
    _discarded = 0;
    _mode = ReplayRouterMode.live;
  }

  /// Vide le journal (remise à vide en direct) ; t0 repart de zéro.
  void clearJournal() {
    _journal.clear();
    _fullSignaled = false;
    _emitSize();
  }

  /// Pousse un événement du lecteur vers le gate (mode rejeu seulement).
  void inject(A2uiEnvelopeReceived event) {
    if (_disposed || _mode != ReplayRouterMode.replay) return;
    _output.add(event);
  }

  void _emitSize() {
    if (!_sizes.isClosed) _sizes.add(_journal.length);
  }

  /// Annule l'abonnement et ferme les sorties. Idempotent.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_subscription.cancel());
    unawaited(_output.close());
    unawaited(_sizes.close());
    unawaited(_full.close());
  }
}
