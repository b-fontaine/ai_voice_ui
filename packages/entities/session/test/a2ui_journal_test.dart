import 'package:a2ui_core/a2ui_core.dart' show A2uiMessage;
import 'package:entity_session/entity_session.dart';
import 'package:test/test.dart';

Map<String, Object?> _delete(String id) => <String, Object?>{
  'version': 'v0.9',
  'deleteSurface': <String, Object?>{'surfaceId': id},
};

Map<String, Object?> _create(String id) => <String, Object?>{
  'version': 'v0.9',
  'createSurface': <String, Object?>{
    'surfaceId': id,
    'catalogId': 'https://a2ui.org/specification/v0_9/basic_catalog.json',
  },
};

A2uiEnvelopeReceived _event(
  Map<String, Object?> raw, {
  String? agent,
  String? task,
}) => A2uiEnvelopeReceived(
  message: A2uiMessage.fromJson(raw),
  raw: raw,
  agent: agent,
  task: task,
);

void main() {
  test('enregistre dans l\'ordre, seq depuis 0, avec agent et tâche', () {
    final A2uiJournal journal = A2uiJournal(maxEntries: 10);
    journal.append(_event(_create('a'), agent: 'x', task: 't1'), 1000);
    journal.append(_event(_delete('a')), 1500);

    expect(journal.length, 2);
    expect(journal.entries.map((JournalEntry e) => e.seq), <int>[0, 1]);
    expect(journal.entries.first.agent, 'x');
    expect(journal.entries.first.task, 't1');
    expect(journal.entries.last.agent, isNull);
  });

  test('t0 est fixé au premier ajout, tMs relatif', () {
    final A2uiJournal journal = A2uiJournal(maxEntries: 10);
    journal.append(_event(_create('a')), 5000);
    journal.append(_event(_delete('a')), 5750);

    expect(journal.entries.map((JournalEntry e) => e.tMs), <int>[0, 750]);
  });

  test('tMs reste croissant si l\'horloge recule', () {
    final A2uiJournal journal = A2uiJournal(maxEntries: 10);
    journal.append(_event(_create('a')), 5000);
    journal.append(_event(_delete('a')), 5400);
    journal.append(_event(_delete('b')), 5100);
    journal.append(_event(_delete('c')), 5600);

    expect(journal.entries.map((JournalEntry e) => e.tMs), <int>[
      0,
      400,
      400,
      600,
    ]);
  });

  test('raw est une copie profonde non modifiable', () {
    final Map<String, Object?> raw = _delete('a');
    final A2uiJournal journal = A2uiJournal(maxEntries: 10);
    journal.append(_event(raw), 0);

    (raw['deleteSurface']! as Map<String, Object?>)['surfaceId'] = 'zzz';
    final Map<String, Object?> stored = journal.entries.single.raw;

    expect(
      (stored['deleteSurface']! as Map<String, Object?>)['surfaceId'],
      'a',
    );
    expect(() => stored['x'] = 1, throwsUnsupportedError);
    expect(
      () => (stored['deleteSurface']! as Map<String, Object?>)['x'] = 1,
      throwsUnsupportedError,
    );
  });

  test('entries est une vue non modifiable', () {
    final A2uiJournal journal = A2uiJournal(maxEntries: 10);
    journal.append(_event(_create('a')), 0);

    expect(() => journal.entries.clear(), throwsUnsupportedError);
  });

  test('toString n\'expose ni raw ni message', () {
    final A2uiJournal journal = A2uiJournal(maxEntries: 10);
    journal.append(_event(_delete('secret-surface')), 0);

    final String text = journal.entries.single.toString();
    expect(text, isNot(contains('secret-surface')));
    expect(text, isNot(contains('deleteSurface')));
  });

  test('plafond : n\'évince pas, cesse d\'enregistrer et expose isFull', () {
    final A2uiJournal journal = A2uiJournal(maxEntries: 2);
    expect(journal.isFull, isFalse);
    journal.append(_event(_create('a')), 0);
    journal.append(_event(_delete('a')), 10);
    expect(journal.isFull, isTrue);
    journal.append(_event(_delete('b')), 20);

    expect(journal.length, 2);
    expect(journal.entries.first.seq, 0);
    expect(
      (journal.entries.last.raw['deleteSurface']!
          as Map<String, Object?>)['surfaceId'],
      'a',
    );
  });

  test('clear vide le journal et remet t0 et seq à zéro', () {
    final A2uiJournal journal = A2uiJournal(maxEntries: 2);
    journal.append(_event(_create('a')), 1000);
    journal.append(_event(_delete('a')), 2000);
    journal.clear();

    expect(journal.length, 0);
    expect(journal.isFull, isFalse);
    expect(journal.hasCreateSurface, isFalse);

    journal.append(_event(_create('b')), 9000);
    journal.append(_event(_delete('b')), 9100);
    expect(journal.entries.map((JournalEntry e) => e.seq), <int>[0, 1]);
    expect(journal.entries.map((JournalEntry e) => e.tMs), <int>[0, 100]);
  });

  test('hasCreateSurface exige un createSurface', () {
    final A2uiJournal journal = A2uiJournal(maxEntries: 10);
    expect(journal.hasCreateSurface, isFalse);
    journal.append(_event(_delete('a')), 0);
    expect(journal.hasCreateSurface, isFalse);
    journal.append(_event(_create('a')), 10);
    expect(journal.hasCreateSurface, isTrue);
  });
}
