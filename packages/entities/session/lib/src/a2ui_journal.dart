import 'dart:collection' show UnmodifiableListView;
import 'dart:math' as math;

import 'package:a2ui_core/a2ui_core.dart'
    show A2uiMessage, CreateSurfaceMessage;

import 'session_event.dart' show A2uiEnvelopeReceived;

/// Une enveloppe A2UI enregistrée, avec sa date relative au premier message.
///
/// Le contenu (`raw`, `message`) peut provenir d'un modèle de langage : il
/// n'apparaît jamais dans [toString], donc ni dans les logs ni dans un
/// `errorSink`.
final class JournalEntry {
  JournalEntry({
    required this.seq,
    required this.tMs,
    required Map<String, Object?> raw,
    required this.message,
    this.agent,
    this.task,
  }) : raw = _freezeMap(raw);

  /// Rang d'enregistrement, croissant depuis 0.
  final int seq;

  /// Millisecondes écoulées depuis le premier message du journal.
  final int tMs;

  /// Enveloppe brute : copie profonde non modifiable.
  final Map<String, Object?> raw;

  final A2uiMessage message;
  final String? agent;
  final String? task;

  @override
  String toString() => 'JournalEntry(seq: $seq, tMs: $tMs)';
}

Map<String, Object?> _freezeMap(Map<Object?, Object?> source) =>
    Map<String, Object?>.unmodifiable(<String, Object?>{
      for (final MapEntry<Object?, Object?> e in source.entries)
        e.key! as String: _freeze(e.value),
    });

Object? _freeze(Object? value) => switch (value) {
  final Map<Object?, Object?> m => _freezeMap(m),
  final List<Object?> l => List<Object?>.unmodifiable(l.map(_freeze)),
  _ => value,
};

/// Journal en mémoire des enveloppes A2UI reçues en direct, pour le rejeu.
///
/// Jamais sérialisé, écrit sur disque ni journalisé. Au plafond
/// [maxEntries], le journal cesse d'enregistrer au lieu d'évincer les plus
/// anciennes entrées, afin qu'un rejeu ne soit jamais tronqué en son début.
final class A2uiJournal {
  A2uiJournal({required this.maxEntries});

  final int maxEntries;

  final List<JournalEntry> _entries = <JournalEntry>[];
  late final UnmodifiableListView<JournalEntry> _view =
      UnmodifiableListView<JournalEntry>(_entries);
  int? _t0;
  bool _hasCreateSurface = false;

  /// Vue non modifiable des entrées, dans l'ordre d'enregistrement.
  List<JournalEntry> get entries => _view;

  int get length => _entries.length;

  bool get isFull => _entries.length >= maxEntries;

  /// Vrai si une entrée au moins crée une surface (journal « jouable »).
  bool get hasCreateSurface => _hasCreateSurface;

  /// Enregistre [event] à l'instant [nowMs]. Le premier ajout fixe t0 ;
  /// `tMs` ne décroît jamais, même si l'horloge recule. Sans effet si plein.
  void append(A2uiEnvelopeReceived event, int nowMs) {
    if (isFull) return;
    final int t0 = _t0 ??= nowMs;
    final int previous = _entries.isEmpty ? 0 : _entries.last.tMs;
    _entries.add(
      JournalEntry(
        seq: _entries.length,
        tMs: math.max(previous, nowMs - t0),
        raw: event.raw,
        message: event.message,
        agent: event.agent,
        task: event.task,
      ),
    );
    if (event.message is CreateSurfaceMessage) _hasCreateSurface = true;
  }

  /// Vide le journal et remet t0 à zéro.
  void clear() {
    _entries.clear();
    _t0 = null;
    _hasCreateSurface = false;
  }
}
