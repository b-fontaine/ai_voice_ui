import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_canvas/app/scenario/scenario_player.dart';
import 'package:shared_core/shared_core.dart';

/// Faux paquet d'assets : frontière plateforme, contenu par chemin.
class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this.assets);

  final Map<String, String> assets;
  final List<String> requested = <String>[];

  @override
  Future<ByteData> load(String key) async {
    requested.add(key);
    final text = assets[key];
    if (text == null) throw FlutterError('asset absent : $key');
    return ByteData.sublistView(Uint8List.fromList(text.codeUnits));
  }
}

/// Paquet d'assets en octets (l'asset contient de l'UTF-8).
class _Utf8Bundle extends CachingAssetBundle {
  _Utf8Bundle(this.assets);

  final Map<String, List<int>> assets;

  @override
  Future<ByteData> load(String key) async {
    final bytes = assets[key];
    if (bytes == null) throw FlutterError('asset absent : $key');
    return ByteData.sublistView(Uint8List.fromList(bytes));
  }
}

const _jsonl = '''
{"t_ms": 0, "message": {"version":"v0.9","createSurface":{"surfaceId":"s1","catalogId":"c"}}}
{"t_ms": 200, "message": {"version":"v0.9","updateComponents":{"surfaceId":"s1","components":[]}}}

{"t_ms": 500, "message": {"version":"v0.9","updateDataModel":{"surfaceId":"s1"}}}
''';

void main() {
  group('ScenarioPlayer', () {
    test(
      'envoie les messages dans l\'ordre depuis replays/<scénario>.jsonl',
      () async {
        final bundle = _FakeBundle(<String, String>{
          'assets/replays/demo.jsonl': _jsonl,
        });
        final delays = <Duration>[];
        final player = ScenarioPlayer(
          bundle: bundle,
          delay: (d) async => delays.add(d),
        );

        final received = await player.messages('demo').toList();

        expect(bundle.requested, <String>['assets/replays/demo.jsonl']);
        expect(
          received.map(
            (m) => m.toJson().keys.toSet().difference({'version'}).single,
          ),
          <String>['createSurface', 'updateComponents', 'updateDataModel'],
        );
        expect(delays, const <Duration>[
          Duration(milliseconds: 200),
          Duration(milliseconds: 300),
        ]);
      },
    );

    test('lit l\'asset act1-replay versionné : douze messages que le gate '
        'valide tous (toJson = ligne brute)', () async {
      final file = File('assets/replays/act1-replay.jsonl');
      final bundle = _Utf8Bundle(<String, List<int>>{
        'assets/replays/act1-replay.jsonl': file.readAsBytesSync(),
      });
      final raws = const LineSplitter()
          .convert(utf8.decode(file.readAsBytesSync()))
          .map((l) => (jsonDecode(l) as Map<String, Object?>)['message'])
          .toList();

      final messages = await ScenarioPlayer(
        bundle: bundle,
        delay: (_) async {},
      ).messages('act1-replay').toList();

      expect(messages, hasLength(12));
      expect(messages.map((m) => m.toJson()), raws);
    });

    test('scénario inconnu : l\'erreur remonte', () async {
      final player = ScenarioPlayer(bundle: _FakeBundle(<String, String>{}));

      expect(player.messages('absent').toList(), throwsA(isA<FlutterError>()));
    });

    test('ligne invalide : A2uiReplayFormatException', () async {
      final player = ScenarioPlayer(
        bundle: _FakeBundle(<String, String>{
          'assets/replays/mauvais.jsonl': 'pas du json',
        }),
      );

      expect(
        player.messages('mauvais').toList(),
        throwsA(isA<A2uiReplayFormatException>()),
      );
    });
  });
}
