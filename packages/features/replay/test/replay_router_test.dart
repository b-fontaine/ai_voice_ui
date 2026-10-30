import 'dart:async';

import 'package:a2ui_core/a2ui_core.dart' show A2uiMessage;
import 'package:entity_session/entity_session.dart';
import 'package:feature_replay/feature_replay.dart';
import 'package:flutter_test/flutter_test.dart';

A2uiEnvelopeReceived _create(String id) {
  final Map<String, Object?> raw = <String, Object?>{
    'version': 'v0.9',
    'createSurface': <String, Object?>{
      'surfaceId': id,
      'catalogId': 'https://a2ui.org/specification/v0_9/basic_catalog.json',
    },
  };
  return A2uiEnvelopeReceived(message: A2uiMessage.fromJson(raw), raw: raw);
}

A2uiEnvelopeReceived _delete(String id) {
  final Map<String, Object?> raw = <String, Object?>{
    'version': 'v0.9',
    'deleteSurface': <String, Object?>{'surfaceId': id},
  };
  return A2uiEnvelopeReceived(message: A2uiMessage.fromJson(raw), raw: raw);
}

class _Rig {
  _Rig({int maxEntries = 100}) {
    journal = A2uiJournal(maxEntries: maxEntries);
    router = ReplayRouter(
      live: live.stream,
      journal: journal,
      nowMs: () => now,
    );
    router.events.listen(out.add, onError: errors.add);
  }

  final StreamController<SessionEvent> live =
      StreamController<SessionEvent>.broadcast(sync: true);
  late final A2uiJournal journal;
  late final ReplayRouter router;
  final List<SessionEvent> out = <SessionEvent>[];
  final List<Object> errors = <Object>[];
  int now = 1000;
}

void main() {
  test('en direct : enregistre puis transmet les enveloppes A2UI', () {
    final _Rig rig = _Rig();
    final A2uiEnvelopeReceived a = _create('a');
    rig.live.add(a);
    rig.now = 1400;
    final A2uiEnvelopeReceived b = _delete('a');
    rig.live.add(b);

    expect(rig.out, <SessionEvent>[a, b]);
    expect(rig.journal.length, 2);
    expect(rig.journal.entries.map((JournalEntry e) => e.tMs), <int>[0, 400]);
    expect(rig.router.hasPlayableJournal, isTrue);
  });

  test('en direct : les autres événements passent sans être enregistrés', () {
    final _Rig rig = _Rig();
    const SessionEvent other = OrbLevelChanged(0.5);
    rig.live.add(other);

    expect(rig.out, <SessionEvent>[other]);
    expect(rig.journal.length, 0);
    expect(rig.router.hasPlayableJournal, isFalse);
  });

  test('journalSize émet à chaque ajout et à chaque vidage', () async {
    final _Rig rig = _Rig();
    final List<int> sizes = <int>[];
    rig.router.journalSize.listen(sizes.add);
    rig.live.add(_create('a'));
    rig.live.add(_delete('a'));
    rig.router.clearJournal();
    await Future<void>.delayed(Duration.zero);

    expect(sizes, <int>[1, 2, 0]);
    expect(rig.journal.length, 0);
  });

  test('journal plein : l\'enveloppe est transmise mais plus enregistrée', () {
    final _Rig rig = _Rig(maxEntries: 1);
    rig.live.add(_create('a'));
    final A2uiEnvelopeReceived b = _delete('a');
    rig.live.add(b);

    expect(rig.out.last, b);
    expect(rig.journal.length, 1);
  });

  test('en rejeu : les événements vivants sont jetés et comptés', () {
    final _Rig rig = _Rig();
    rig.live.add(_create('a'));
    rig.out.clear();

    rig.router.enterReplay();
    rig.live.add(_delete('a'));
    rig.live.add(const OrbLevelChanged(0.2));

    expect(rig.out, isEmpty);
    expect(rig.journal.length, 1);
    expect(rig.router.discardedLiveCount, 2);
  });

  test('message vivant dans la même pile que enterReplay : ni rendu ni '
      'enregistré', () {
    final _Rig rig = _Rig();
    rig.live.add(_create('a'));
    rig.out.clear();

    final List<JournalEntry> frozen = rig.router.enterReplay();
    rig.live.add(_delete('a')); // aucun tour de boucle entre les deux

    expect(frozen.length, 1);
    expect(rig.out, isEmpty);
    expect(rig.journal.length, 1);
  });

  test('enterReplay renvoie une copie figée non modifiable', () {
    final _Rig rig = _Rig();
    rig.live.add(_create('a'));
    final List<JournalEntry> frozen = rig.router.enterReplay();

    expect(() => frozen.clear(), throwsUnsupportedError);
    rig.journal.append(_delete('a'), 2000); // ajout postérieur direct
    expect(frozen.length, 1);
  });

  test('en rejeu : inject transmet l\'événement du lecteur', () {
    final _Rig rig = _Rig();
    rig.router.enterReplay();
    final A2uiEnvelopeReceived a = _create('a');
    rig.router.inject(a);

    expect(rig.out, <SessionEvent>[a]);
    expect(rig.journal.length, 0);
  });

  test('en direct : inject est ignoré', () {
    final _Rig rig = _Rig();
    rig.router.inject(_create('a'));

    expect(rig.out, isEmpty);
    expect(rig.journal.length, 0);
  });

  test('exitReplay : retour en direct, journal vidé, compteur rendu et remis '
      'à zéro', () {
    final _Rig rig = _Rig();
    rig.live.add(_create('a'));
    rig.router.enterReplay();
    rig.live.add(_delete('a'));
    rig.live.add(_delete('b'));
    rig.out.clear();

    expect(rig.router.exitReplay(), 2);
    expect(rig.router.discardedLiveCount, 0);
    expect(rig.journal.length, 0);
    expect(rig.router.hasPlayableJournal, isFalse);

    rig.now = 5000;
    final A2uiEnvelopeReceived c = _create('c');
    rig.live.add(c);
    expect(rig.out, <SessionEvent>[c]);
    expect(rig.journal.entries.single.tMs, 0); // t0 remis à zéro
    expect(rig.router.mode, ReplayRouterMode.live);
  });

  test(
    'liveDone se complète à la fin du flux vivant sans fermer events',
    () async {
      final _Rig rig = _Rig();
      bool outputDone = false;
      final StreamController<SessionEvent> live =
          StreamController<SessionEvent>();
      final A2uiJournal journal = A2uiJournal(maxEntries: 10);
      final ReplayRouter router = ReplayRouter(
        live: live.stream,
        journal: journal,
        nowMs: () => 0,
      );
      router.events.listen((_) {}, onDone: () => outputDone = true);
      bool done = false;
      unawaited(router.liveDone.then((_) => done = true));

      await live.close();
      await Future<void>.delayed(Duration.zero);

      expect(done, isTrue);
      expect(outputDone, isFalse);
      router.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(outputDone, isTrue);
      await rig.live.close();
    },
  );

  test('les erreurs du flux vivant sont relayées à events', () async {
    final _Rig rig = _Rig();
    rig.live.addError(StateError('boom'));
    await Future<void>.delayed(Duration.zero);

    expect(rig.errors.single, isA<StateError>());
  });

  test('dispose : annule l\'abonnement, ferme la sortie, idempotent', () async {
    final _Rig rig = _Rig();
    bool closed = false;
    final StreamController<SessionEvent> live = StreamController<SessionEvent>(
      onCancel: () => closed = true,
    );
    final ReplayRouter router = ReplayRouter(
      live: live.stream,
      journal: A2uiJournal(maxEntries: 10),
      nowMs: () => 0,
    );
    final List<SessionEvent> out = <SessionEvent>[];
    router.events.listen(out.add);

    router.dispose();
    router.dispose();
    router.enterReplay();
    router.inject(_create('x'));
    await Future<void>.delayed(Duration.zero);

    expect(closed, isTrue);
    expect(out, isEmpty);
    expect(rig.live.hasListener, isTrue); // le banc principal est intact
  });
}
