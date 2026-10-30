import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';

const _createSurface =
    '{"t_ms": 0, "message": {"version":"v0.9","createSurface":{"surfaceId":"s1","catalogId":"c"}}}';
const _updateComponents =
    '{"t_ms": 300, "message": {"version":"v0.9","updateComponents":{"surfaceId":"s1","components":[]}}}';
const _updateDataModel =
    '{"t_ms": 1000, "message": {"version":"v0.9","updateDataModel":{"surfaceId":"s1"}}}';

void main() {
  group('A2uiReplaySource', () {
    late List<Duration> delays;

    A2uiReplaySource build(List<String> lines) {
      delays = [];
      return A2uiReplaySource(
        lines: Stream.fromIterable(lines),
        delay: (d) async => delays.add(d),
      );
    }

    test('émet les trois messages dans l\'ordre', () async {
      final source = build([
        _createSurface,
        _updateComponents,
        _updateDataModel,
      ]);

      final messages = await source.messages().toList();

      expect(
        messages.map((m) => m.toJson().keys.toSet().difference({'version'})),
        [
          {'createSurface'},
          {'updateComponents'},
          {'updateDataModel'},
        ],
      );
      expect(messages.every((m) => m.version == 'v0.9'), isTrue);
    });

    test('entries() fournit la ligne brute avec le message décodé', () async {
      final source = build([_createSurface, _updateComponents]);

      final entries = await source.entries().toList();

      expect(entries.map((e) => e.raw), [
        {
          'version': 'v0.9',
          'createSurface': {'surfaceId': 's1', 'catalogId': 'c'},
        },
        {
          'version': 'v0.9',
          'updateComponents': {'surfaceId': 's1', 'components': <Object?>[]},
        },
      ]);
      // Le décodeur normalise (il ajoute `sendDataModel`) : la ligne brute,
      // elle, reste celle de la source.
      expect(
        (entries.first.message.toJson()['createSurface']
            as Map<String, Object?>)['sendDataModel'],
        isFalse,
      );
    });

    test('attend l\'écart relatif entre deux t_ms', () async {
      final source = build([
        _createSurface,
        _updateComponents,
        _updateDataModel,
      ]);

      await source.messages().toList();

      expect(delays, [
        const Duration(milliseconds: 300),
        const Duration(milliseconds: 700),
      ]);
    });

    test('ignore les lignes vides', () async {
      final source = build(['', _createSurface, '  ']);

      expect(await source.messages().length, 1);
    });

    test('rejette un JSON invalide avec le numéro de ligne', () {
      final source = build([_createSurface, '{pas du json']);

      expect(
        source.messages().toList(),
        throwsA(
          isA<A2uiReplayFormatException>()
              .having((e) => e.lineNumber, 'lineNumber', 2)
              .having((e) => e.message, 'message', contains('JSON')),
        ),
      );
    });

    test('rejette une version différente de v0.9', () {
      final source = build([
        '{"t_ms": 0, "message": {"version":"v0.8","createSurface":{}}}',
      ]);

      expect(
        source.messages().toList(),
        throwsA(
          isA<A2uiReplayFormatException>().having(
            (e) => e.message,
            'message',
            contains('v0.9'),
          ),
        ),
      );
    });

    test('rejette une ligne à deux corps avec le numéro de ligne', () {
      final source = build([
        _createSurface,
        '{"t_ms": 10, "message": {"version":"v0.9",'
            '"createSurface":{"surfaceId":"s1","catalogId":"c"},'
            '"updateComponents":{"surfaceId":"s1","components":[]}}}',
      ]);

      expect(
        source.messages().toList(),
        throwsA(
          isA<A2uiReplayFormatException>()
              .having((e) => e.lineNumber, 'lineNumber', 2)
              .having((e) => e.message, 'message', contains('exactly one')),
        ),
      );
    });

    test('rejette un corps mal formé avec le numéro de ligne', () {
      final source = build([
        '{"t_ms": 0, "message": {"version":"v0.9","createSurface":{}}}',
      ]);

      expect(
        source.messages().toList(),
        throwsA(
          isA<A2uiReplayFormatException>().having(
            (e) => e.lineNumber,
            'lineNumber',
            1,
          ),
        ),
      );
    });

    test('rejette un t_ms manquant', () {
      final source = build(['{"message": {"version":"v0.9"}}']);

      expect(
        source.messages().toList(),
        throwsA(
          isA<A2uiReplayFormatException>().having(
            (e) => e.message,
            'message',
            contains('t_ms'),
          ),
        ),
      );
    });

    test('rejette un t_ms décroissant', () {
      final source = build([_updateComponents, _createSurface]);

      expect(
        source.messages().toList(),
        throwsA(
          isA<A2uiReplayFormatException>()
              .having((e) => e.lineNumber, 'lineNumber', 2)
              .having((e) => e.message, 'message', contains('décroissant')),
        ),
      );
    });

    test('rejette un message absent', () {
      final source = build(['{"t_ms": 0}']);

      expect(
        source.messages().toList(),
        throwsA(isA<A2uiReplayFormatException>()),
      );
    });
  });
}
