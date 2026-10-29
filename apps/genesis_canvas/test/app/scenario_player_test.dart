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

const _jsonl = '''
{"t_ms": 0, "message": {"version":"v0.9","createSurface":{"surfaceId":"s1"}}}
{"t_ms": 200, "message": {"version":"v0.9","updateComponents":{"surfaceId":"s1"}}}

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
        final received = <Map<String, dynamic>>[];
        final delays = <Duration>[];
        final player = ScenarioPlayer(
          bundle: bundle,
          onMessage: received.add,
          delay: (d) async => delays.add(d),
        );

        await player.play('demo');

        expect(bundle.requested, <String>['assets/replays/demo.jsonl']);
        expect(
          received.map((m) => m.keys.toSet().difference({'version'}).single),
          <String>['createSurface', 'updateComponents', 'updateDataModel'],
        );
        expect(delays, const <Duration>[
          Duration(milliseconds: 200),
          Duration(milliseconds: 300),
        ]);
      },
    );

    test('scénario inconnu : l\'erreur remonte', () async {
      final player = ScenarioPlayer(
        bundle: _FakeBundle(<String, String>{}),
        onMessage: (_) {},
      );

      expect(player.play('absent'), throwsA(isA<FlutterError>()));
    });

    test('ligne invalide : A2uiReplayFormatException', () async {
      final player = ScenarioPlayer(
        bundle: _FakeBundle(<String, String>{
          'assets/replays/mauvais.jsonl': 'pas du json',
        }),
        onMessage: (_) {},
      );

      expect(player.play('mauvais'), throwsA(isA<A2uiReplayFormatException>()));
    });
  });
}
