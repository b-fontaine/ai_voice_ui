import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

/// Façades publiques des espacements, rayons et ombres (pdr-0084 U1, U9) :
/// valeurs du design system du 2026-11-02 (`tokens.json`).
void main() {
  test('SceneSpace : 4, 8, 12, 16, 24, 32 px', () {
    expect(SceneSpace.space1, 4.0);
    expect(SceneSpace.space2, 8.0);
    expect(SceneSpace.space3, 12.0);
    expect(SceneSpace.space4, 16.0);
    expect(SceneSpace.space6, 24.0);
    expect(SceneSpace.space8, 32.0);
  });

  test('SceneRadius : 6, 10, 16, 999 px, en double et en BorderRadius', () {
    expect(SceneRadius.sm, 6.0);
    expect(SceneRadius.md, 10.0);
    expect(SceneRadius.lg, 16.0);
    expect(SceneRadius.pill, 999.0);
    expect(SceneRadius.borderSm, BorderRadius.circular(6));
    expect(SceneRadius.borderMd, BorderRadius.circular(10));
    expect(SceneRadius.borderLg, BorderRadius.circular(16));
    expect(SceneRadius.borderPill, BorderRadius.circular(999));
  });

  group('SceneShadow : List<BoxShadow> constantes', () {
    // blurRadius = (B / 2 - 0,5) / 0,57735 pour un flou CSS B > 1.
    double r(double cssBlur) => (cssBlur / 2 - 0.5) / 0.57735;

    test(
      'panel : ombre externe seule (le filet inset est un token couleur)',
      () {
        expect(SceneShadow.panel, <BoxShadow>[
          BoxShadow(
            color: const Color(0x66000000),
            offset: const Offset(0, 24),
            blurRadius: r(48),
          ),
        ]);
      },
    );

    test('glowSignal : anneau de 1 px sans flou, puis halo de 28 px', () {
      expect(SceneShadow.glowSignal, <BoxShadow>[
        const BoxShadow(color: Color(0x553DE8FF), spreadRadius: 1),
        BoxShadow(color: const Color(0x333DE8FF), blurRadius: r(28)),
      ]);
    });

    test('glowNogo : anneau de 1 px sans flou, puis halo de 24 px', () {
      expect(SceneShadow.glowNogo, <BoxShadow>[
        const BoxShadow(color: Color(0x66FF5A76), spreadRadius: 1),
        BoxShadow(color: const Color(0x40FF5A76), blurRadius: r(24)),
      ]);
    });

    test('glowPlasma : halo de 40 px', () {
      expect(SceneShadow.glowPlasma, <BoxShadow>[
        BoxShadow(color: const Color(0x66A58BFF), blurRadius: r(40)),
      ]);
    });

    test('le sigma rendu par Flutter vaut la moitié du flou CSS', () {
      expect(SceneShadow.panel.single.blurSigma, closeTo(24, 1e-9));
      expect(SceneShadow.glowSignal.last.blurSigma, closeTo(14, 1e-9));
      expect(SceneShadow.glowNogo.last.blurSigma, closeTo(12, 1e-9));
      expect(SceneShadow.glowPlasma.single.blurSigma, closeTo(20, 1e-9));
      // Les anneaux n'ont pas de flou.
      expect(SceneShadow.glowSignal.first.blurSigma, 0);
    });
  });
}
