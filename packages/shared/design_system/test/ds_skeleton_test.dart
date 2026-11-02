import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

/// Squelette (RG-02) : sa pulsation passe par `SceneMotionScope.loop`, avec la
/// période du jeton `motion.skeleton`, et s'arrête sous « animations coupées ».
Widget _host({bool disabled = false, double speed = 1, bool animate = true}) =>
    MaterialApp(
      theme: ThemeData(extensions: const [SceneTheme.dark()]),
      home: SceneMotionScope(
        disabled: disabled,
        speed: speed,
        child: Scaffold(
          body: SizedBox(
            width: 100,
            height: 100,
            child: DsSkeleton(key: const Key('sk'), animate: animate),
          ),
        ),
      ),
    );

Color _fill(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find.descendant(
      of: find.byKey(const Key('sk')),
      matching: find.byType(DecoratedBox),
    ),
  );
  return (box.decoration as BoxDecoration).color!;
}

void main() {
  testWidgets('par défaut le squelette est statique', (tester) async {
    await tester.pumpWidget(_host(animate: false));
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpAndSettle();
  });

  testWidgets('animé : la pulsation suit la période du jeton, aller-retour', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    final Color start = _fill(tester);

    await tester.pump(SceneMotion.skeleton);
    final Color peak = _fill(tester);
    expect(peak, isNot(start));

    await tester.pump(SceneMotion.skeleton);
    expect(_fill(tester), start, reason: 'retour à la couleur de départ');
  });

  testWidgets('la vitesse de rejeu 2 divise la période', (tester) async {
    await tester.pumpWidget(_host(speed: 2));
    final Color start = _fill(tester);
    await tester.pump(SceneMotion.skeleton ~/ 2);
    final Color peak = _fill(tester);
    expect(peak, isNot(start));
    await tester.pump(SceneMotion.skeleton ~/ 2);
    expect(_fill(tester), start);
  });

  testWidgets('animations coupées : couleur fixe, aucun ticker actif', (
    tester,
  ) async {
    await tester.pumpWidget(_host(disabled: true));
    expect(tester.binding.transientCallbackCount, 0);
    final Color color = _fill(tester);
    await tester.pump(const Duration(seconds: 3));
    expect(_fill(tester), color);
    await tester.pumpAndSettle();
  });

  testWidgets('bascule de disabled : arrêt puis reprise', (tester) async {
    await tester.pumpWidget(_host());
    expect(tester.binding.transientCallbackCount, greaterThan(0));

    await tester.pumpWidget(_host(disabled: true));
    expect(tester.binding.transientCallbackCount, 0);

    await tester.pumpWidget(_host());
    expect(tester.binding.transientCallbackCount, greaterThan(0));
  });

  testWidgets('animate passe à false : la pulsation s\'arrête', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpWidget(_host(animate: false));
    expect(tester.binding.transientCallbackCount, 0);
  });
}
