import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_backend_channel/shared_backend_channel.dart';

AppChannelEnvelope _env({
  String type = 'transcript',
  int tMs = 120,
  String? agent,
  String? task,
}) => AppChannelEnvelope(
  version: 1,
  type: type,
  session: 's1',
  tMs: tMs,
  data: const {'text': 'bonjour'},
  agent: agent,
  task: task,
);

void main() {
  late Directory dir;
  late int now;
  late List<Object> errors;

  EnvelopeLog log(String? path) =>
      EnvelopeLog(path: path, nowUnixMs: () => now, onError: errors.add);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('envelope_log_test');
    now = 1700000000000;
    errors = [];
  });

  tearDown(() async {
    await dir.delete(recursive: true);
  });

  test('inactif quand le chemin est nul ou vide : aucun fichier', () async {
    for (final path in <String?>[null, '']) {
      final journal = log(path);
      expect(journal.isActive, isFalse);
      await journal.open();
      journal.append(_env());
      await journal.close();
    }
    expect(dir.listSync(), isEmpty);
    expect(errors, isEmpty);
  });

  test('écrit une ligne par enveloppe, sans v, avec unix_ms', () async {
    final file = File('${dir.path}/s1.jsonl');
    final journal = log(file.path);
    expect(journal.isActive, isTrue);
    await journal.open();
    journal.append(_env());
    now += 50;
    journal.append(_env(type: 'usage', tMs: 300, agent: 'a', task: 't'));
    await journal.close();

    final lines = file.readAsLinesSync();
    expect(lines, hasLength(2));
    expect(file.readAsStringSync().endsWith('\n'), isTrue);
    final first = jsonDecode(lines[0]) as Map<String, Object?>;
    final second = jsonDecode(lines[1]) as Map<String, Object?>;
    expect(first.containsKey('v'), isFalse);
    expect(first.keys.toList(), ['type', 'session', 't_ms', 'data', 'unix_ms']);
    expect(first['unix_ms'], 1700000000000);
    expect(first['unix_ms'], isNot(first['t_ms']));
    expect(second.keys.toList(), [
      'type',
      'session',
      't_ms',
      'data',
      'agent',
      'task',
      'unix_ms',
    ]);
    expect(second['unix_ms'], 1700000000050);
    expect(second['t_ms'], 300);
  });

  test('rejouable : les lignes redonnent les enveloppes avec v:1', () async {
    final file = File('${dir.path}/s1.jsonl');
    final journal = log(file.path);
    await journal.open();
    final sent = [_env(), _env(type: 'usage', tMs: 5, agent: 'a', task: 't')];
    sent.forEach(journal.append);
    await journal.close();

    final replayed = file.readAsLinesSync().map((line) {
      final map = jsonDecode(line) as Map<String, Object?>
        ..remove('unix_ms')
        ..['v'] = 1;
      return AppChannelEnvelope.parse(jsonEncode(map));
    }).toList();
    expect(replayed, sent);
  });

  test('crée les dossiers parents', () async {
    final file = File('${dir.path}/a/b/s1.jsonl');
    final journal = log(file.path);
    await journal.open();
    journal.append(_env());
    await journal.close();
    expect(file.readAsLinesSync(), hasLength(1));
  });

  test('append avant open est ignoré', () async {
    final file = File('${dir.path}/s1.jsonl');
    final journal = log(file.path);
    journal.append(_env());
    await journal.open();
    journal.append(_env(tMs: 2));
    await journal.close();
    expect(file.readAsLinesSync(), hasLength(1));
  });

  test('open est idempotent', () async {
    final file = File('${dir.path}/s1.jsonl');
    final journal = log(file.path);
    await journal.open();
    await journal.open();
    journal.append(_env());
    await journal.close();
    expect(file.readAsLinesSync(), hasLength(1));
    expect(errors, isEmpty);
  });

  test('append après close est ignoré et close est idempotent', () async {
    final file = File('${dir.path}/s1.jsonl');
    final journal = log(file.path);
    await journal.open();
    journal.append(_env());
    await journal.close();
    await journal.close();
    journal.append(_env(tMs: 2));
    expect(journal.isActive, isFalse);
    expect(file.readAsLinesSync(), hasLength(1));
    expect(errors, isEmpty);
  });

  test('chemin impossible : onError une fois, journal désactivé', () async {
    final blocker = File('${dir.path}/fichier')..writeAsStringSync('x');
    final journal = log('${blocker.path}/s1.jsonl');
    await journal.open();
    journal.append(_env());
    journal.append(_env());
    await journal.close();
    expect(errors, hasLength(1));
    expect(journal.isActive, isFalse);
    expect(blocker.readAsStringSync(), 'x');
  });

  test('ouverture en ajout : une deuxième instance n écrase pas', () async {
    final file = File('${dir.path}/s1.jsonl');
    final a = log(file.path);
    await a.open();
    a.append(_env());
    await a.close();
    final b = log(file.path);
    await b.open();
    b.append(_env(tMs: 2));
    await b.close();
    expect(file.readAsLinesSync(), hasLength(2));
  });
}
