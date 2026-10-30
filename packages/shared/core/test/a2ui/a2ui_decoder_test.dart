import 'package:shared_core/shared_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('A2uiDecoder', () {
    final valid = <String, Map<String, Object?>>{
      'createSurface': {
        'version': 'v0.9',
        'createSurface': {'surfaceId': 's1', 'catalogId': 'c'},
      },
      'updateComponents': {
        'version': 'v0.9',
        'updateComponents': {'surfaceId': 's1', 'components': <Object?>[]},
      },
      'updateDataModel': {
        'version': 'v0.9',
        'updateDataModel': {
          'surfaceId': 's1',
          'path': '/crashFree',
          'value': '99,57 %',
        },
      },
      'deleteSurface': {
        'version': 'v0.9',
        'deleteSurface': {'surfaceId': 's1'},
      },
    };

    for (final entry in valid.entries) {
      test('décode un message ${entry.key} v0.9', () {
        final message = A2uiDecoder.decode(entry.value);
        expect(message.version, 'v0.9');
        expect(message.toJson().keys, contains(entry.key));
      });
    }

    test('accepte une Map<String, dynamic>', () {
      final Map<String, dynamic> raw = Map<String, dynamic>.from(
        valid['deleteSurface']!,
      );
      expect(A2uiDecoder.decode(raw).version, 'v0.9');
    });

    test('refuse une version différente de v0.9', () {
      expect(
        () => A2uiDecoder.decode({
          'version': 'v0.8',
          'createSurface': <String, Object?>{},
        }),
        throwsA(isA<A2uiDecodeException>()),
      );
    });

    test('refuse un corps invalide', () {
      expect(
        () => A2uiDecoder.decode({
          'version': 'v0.9',
          'createSurface': <String, Object?>{},
        }),
        throwsA(isA<A2uiDecodeException>()),
      );
    });

    test('refuse une entrée qui n\'est pas une Map', () {
      for (final raw in <Object?>[null, 'texte', 42, <Object?>[]]) {
        expect(
          () => A2uiDecoder.decode(raw),
          throwsA(isA<A2uiDecodeException>()),
        );
      }
    });

    test('le message d\'erreur ne contient jamais le corps brut', () {
      const secret = 'SECRET-CORPS-123';
      try {
        A2uiDecoder.decode({
          'version': 'v0.9',
          'createSurface': {'surfaceId': secret, 'catalogId': 7},
        });
        fail('une A2uiDecodeException était attendue');
      } on A2uiDecodeException catch (e) {
        expect(e.message, isNot(contains(secret)));
        expect(e.toString(), isNot(contains(secret)));
      }
    });
  });
}
