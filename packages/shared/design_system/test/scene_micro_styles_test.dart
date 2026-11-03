import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

/// Micro-styles de `bundle.css` (pdr-0088 F1, RG-09) : valeurs littérales de la
/// feuille du design system, exposées par `SceneTheme.micro` (objet valeur
/// imbriqué, pas une seconde `ThemeExtension`). Sans couleur : elle vient du
/// rôle du composant (règle F12 : jamais `inkFaint` sous 24 px).
typedef _Row = ({
  TextStyle Function(SceneMicroStyles) pick,
  String family,
  double size,
  double height,
  int wght,
  double? letterSpacing,
});

void main() {
  const mono = SceneFonts.mono;
  const sans = SceneFonts.sans;
  final rows = <String, _Row>{
    'badge': (
      pick: (m) => m.badge,
      family: mono,
      size: 12,
      height: 1,
      wght: 600,
      letterSpacing: 0.96,
    ),
    'badgeLg': (
      pick: (m) => m.badgeLg,
      family: mono,
      size: 18,
      height: 1,
      wght: 600,
      letterSpacing: 1.8,
    ),
    'kpiUnit': (
      pick: (m) => m.kpiUnit,
      family: mono,
      size: 36,
      height: 1,
      wght: 600,
      letterSpacing: 0,
    ),
    'delta': (
      pick: (m) => m.delta,
      family: mono,
      size: 14,
      height: 20 / 14,
      wght: 500,
      letterSpacing: null,
    ),
    'tick': (
      pick: (m) => m.tick,
      family: mono,
      size: 12,
      height: 1,
      wght: 500,
      letterSpacing: null,
    ),
    'legend': (
      pick: (m) => m.legend,
      family: mono,
      size: 13,
      height: 18 / 13,
      wght: 500,
      letterSpacing: null,
    ),
    'chip': (
      pick: (m) => m.chip,
      family: mono,
      size: 13,
      height: 1,
      wght: 500,
      letterSpacing: null,
    ),
    'speed': (
      pick: (m) => m.speed,
      family: mono,
      size: 12,
      height: 1,
      wght: 500,
      letterSpacing: null,
    ),
    'quote': (
      pick: (m) => m.quote,
      family: sans,
      size: 15,
      height: 22 / 15,
      wght: 400,
      letterSpacing: null,
    ),
    'quoteMeta': (
      pick: (m) => m.quoteMeta,
      family: mono,
      size: 12,
      height: 18 / 12,
      wght: 600,
      letterSpacing: null,
    ),
    'agentName': (
      pick: (m) => m.agentName,
      family: sans,
      size: 15,
      height: 20 / 15,
      wght: 600,
      letterSpacing: null,
    ),
    'agentState': (
      pick: (m) => m.agentState,
      family: mono,
      size: 12,
      height: 18 / 12,
      wght: 500,
      letterSpacing: null,
    ),
    'callout': (
      pick: (m) => m.callout,
      family: mono,
      size: 12,
      height: 1,
      wght: 600,
      letterSpacing: null,
    ),
    'segment': (
      pick: (m) => m.segment,
      family: sans,
      size: 13,
      height: 1,
      wght: 600,
      letterSpacing: null,
    ),
    'segmentNo': (
      pick: (m) => m.segmentNo,
      family: mono,
      size: 11,
      height: 1,
      wght: 600,
      letterSpacing: null,
    ),
  };

  final micro = const SceneTheme.dark().micro;

  group('valeurs de bundle.css', () {
    rows.forEach((name, row) {
      test(name, () {
        final style = row.pick(micro);
        expect(style.fontFamily, row.family);
        expect(style.fontFamilyFallback, SceneFonts.fallbackList);
        expect(style.fontSize, row.size);
        expect(style.height, closeTo(row.height, 1e-12));
        expect(style.fontWeight!.value, row.wght);
        expect(style.fontVariations, sceneWeight(row.wght).variations);
        if (row.letterSpacing == null) {
          expect(style.letterSpacing, isNull);
        } else {
          expect(style.letterSpacing, closeTo(row.letterSpacing!, 1e-9));
        }
        expect(style.color, isNull, reason: 'la couleur vient du rôle');
      });
    });
  });

  testWidgets('SceneTheme.of(context).micro est accessible', (tester) async {
    late SceneMicroStyles read;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [SceneTheme.dark()]),
        home: Builder(
          builder: (context) {
            read = SceneTheme.of(context).micro;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(read, SceneTheme.dark().micro);
    expect(read.badge.fontSize, 12);
  });

  group('objet valeur', () {
    test('copyWith remplace un style et conserve les autres', () {
      const custom = TextStyle(fontSize: 99);
      final copy = micro.copyWith(badge: custom);
      expect(copy.badge, custom);
      expect(copy.badgeLg, micro.badgeLg);
      expect(copy.segmentNo, micro.segmentNo);
      expect(micro.copyWith(), micro);
    });

    test('== et hashCode comparent chaque style', () {
      expect(micro, const SceneMicroStyles.dark());
      expect(micro.hashCode, const SceneMicroStyles.dark().hashCode);
      final other = micro.copyWith(segmentNo: const TextStyle(fontSize: 99));
      expect(other, isNot(micro));
    });

    test('lerp interpole style par style', () {
      final other = micro.copyWith(
        badge: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
      );
      expect(micro.lerp(other, 0).badge.fontSize, 12);
      expect(micro.lerp(other, 1).badge.fontSize, 22);
      expect(micro.lerp(other, 0.5).badge.fontSize, 17);
      expect(micro.lerp(other, 0.5).chip, micro.chip);
    });

    test('SceneTheme délègue copyWith, lerp, == et hashCode', () {
      const theme = SceneTheme.dark();
      final changed = theme.copyWith(
        micro: micro.copyWith(tick: const TextStyle(fontSize: 20)),
      );
      expect(changed.micro.tick.fontSize, 20);
      expect(changed.body, theme.body);
      expect(changed, isNot(theme));
      expect(theme.copyWith(), theme);
      expect(theme.copyWith().hashCode, theme.hashCode);
      expect(theme.lerp(changed, 1).micro.tick.fontSize, 20);
      expect(theme.lerp(changed, 0).micro.tick.fontSize, 12);
    });
  });
}
