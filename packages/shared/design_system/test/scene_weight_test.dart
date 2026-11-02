import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

void main() {
  group('sceneWeight : fontWeight = wght', () {
    for (final int wght in <int>[400, 500, 600, 700]) {
      test('w$wght : fontWeight et FontVariation portent la même valeur', () {
        final SceneWeight weight = sceneWeight(wght);
        expect(weight.fontWeight.value, wght);
        expect(weight.variations, hasLength(1));
        expect(weight.variations.single.axis, 'wght');
        expect(weight.variations.single.value, wght.toDouble());
      });
    }

    test('w400 à w700 : les quatre graisses de la scène', () {
      expect(
        <int>[
          for (final int w in <int>[400, 500, 600, 700])
            sceneWeight(w).fontWeight.value,
        ],
        <int>[400, 500, 600, 700],
      );
    });

    test('une valeur hors de l\'axe 1..1000 est refusée', () {
      expect(() => sceneWeight(0), throwsArgumentError);
      expect(() => sceneWeight(1001), throwsArgumentError);
    });
  });

  group('TextStyle.withSceneWeight', () {
    test(
      'applique fontWeight et fontVariations ensemble, sans toucher au reste',
      () {
        const TextStyle base = TextStyle(fontSize: 24, letterSpacing: 1.5);
        final TextStyle styled = base.withSceneWeight(600);
        expect(styled.fontWeight?.value, 600);
        expect(styled.fontVariations, <FontVariation>[
          const FontVariation('wght', 600),
        ]);
        expect(styled.fontSize, 24);
        expect(styled.letterSpacing, 1.5);
      },
    );

    test('remplace une variation de wght existante, garde les autres axes', () {
      const TextStyle base = TextStyle(
        fontVariations: <FontVariation>[
          FontVariation('wght', 300),
          FontVariation('wdth', 90),
        ],
      );
      final TextStyle styled = base.withSceneWeight(700);
      expect(styled.fontVariations, <FontVariation>[
        const FontVariation('wdth', 90),
        const FontVariation('wght', 700),
      ]);
    });
  });
}
