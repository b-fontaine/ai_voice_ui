import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

/// Contenu témoin dont le `State` ne doit jamais être recréé (D-07).
class _Probe extends StatefulWidget {
  const _Probe();

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  Widget build(BuildContext context) =>
      const SizedBox(key: Key('probe-box'), width: 100, height: 50);
}

Widget _host({bool disabled = false, double speed = 1, bool settled = false}) =>
    Directionality(
      textDirection: TextDirection.ltr,
      child: SceneMotionScope(
        disabled: disabled,
        speed: speed,
        child: Align(
          alignment: Alignment.topLeft,
          child: DsRise(settled: settled, child: const _Probe()),
        ),
      ),
    );

double _opacity(WidgetTester t) => t
    .widget<Opacity>(
      find.descendant(of: find.byType(DsRise), matching: find.byType(Opacity)),
    )
    .opacity;

ImageFiltered _filter(WidgetTester t) => t.widget<ImageFiltered>(
  find.descendant(
    of: find.byType(DsRise),
    matching: find.byType(ImageFiltered),
  ),
);

/// Décalage vertical du bord supérieur par rapport à sa place finale : la
/// mise à l'échelle part du haut et ne le déplace pas.
double _dy(WidgetTester t) =>
    t.getTopLeft(find.byKey(const Key('probe-box'))).dy;

double _scaleX(WidgetTester t) => t
    .renderObject<RenderBox>(find.byKey(const Key('probe-box')))
    .getTransformTo(null)
    .storage[0];

void main() {
  testWidgets('départ : transparent, flou de 4, décalé de 10, échelle .985', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    expect(_opacity(tester), 0);
    final f = _filter(tester);
    expect(f.enabled, isTrue);
    expect(f.imageFilter, ImageFilter.blur(sigmaX: 4, sigmaY: 4));
    expect(_dy(tester), closeTo(10, 0.001));
    expect(_scaleX(tester), closeTo(0.985, 1e-6));
  });

  testWidgets('à mi-parcours : en cours ; à 480 ms : net, en place, opaque', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.pump(); // image de départ du ticker
    await tester.pump(const Duration(milliseconds: 240));
    expect(_opacity(tester), inExclusiveRange(0.3, 1.0));
    expect(_filter(tester).enabled, isTrue);
    expect(_dy(tester), inExclusiveRange(0, 10));
    expect(_scaleX(tester), inExclusiveRange(0.985, 1));

    await tester.pump(const Duration(milliseconds: 241));
    expect(_opacity(tester), 1);
    expect(_filter(tester).enabled, isFalse);
    expect(_dy(tester), 0);
    expect(_scaleX(tester), 1);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('le flou suit σ = 4 (1 - t) sur la courbe du design system', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    final double t = SceneMotion.curve.transform(0.25);
    expect(
      _filter(tester).imageFilter,
      ImageFilter.blur(sigmaX: 4 * (1 - t), sigmaY: 4 * (1 - t)),
    );
    expect(_opacity(tester), closeTo(t, 1e-6));
    expect(_dy(tester), closeTo(10 * (1 - t), 1e-6));
  });

  testWidgets('vitesse 2 : terminé en 240 ms', (tester) async {
    await tester.pumpWidget(_host(speed: 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(_opacity(tester), lessThan(1));
    await tester.pump(const Duration(milliseconds: 121));
    expect(_opacity(tester), 1);
  });

  testWidgets('disableAnimations : net et en place dès la première image', (
    tester,
  ) async {
    await tester.pumpWidget(_host(disabled: true));
    expect(_opacity(tester), 1);
    expect(_filter(tester).enabled, isFalse);
    expect(_dy(tester), 0);
    expect(_scaleX(tester), 1);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('coupé en cours d\'apparition : net aussitôt', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_opacity(tester), lessThan(1));

    await tester.pumpWidget(_host(disabled: true));

    expect(_opacity(tester), 1);
    expect(_filter(tester).enabled, isFalse);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('settled : déjà en place, rien ne se joue', (tester) async {
    await tester.pumpWidget(_host(settled: true));
    expect(_opacity(tester), 1);
    expect(_filter(tester).enabled, isFalse);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('arbre constant et même State de l\'enfant avant et après', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    final Finder rise = find.byType(DsRise);
    expect(
      find.descendant(of: rise, matching: find.byType(Opacity)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: rise, matching: find.byType(Transform)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: rise, matching: find.byType(ImageFiltered)),
      findsOneWidget,
    );
    final State before = tester.state(find.byType(_Probe));
    final Element opacityBefore = tester.element(
      find.descendant(of: rise, matching: find.byType(Opacity)),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.state(find.byType(_Probe)), same(before));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.state(find.byType(_Probe)), same(before));
    expect(
      find.descendant(of: rise, matching: find.byType(Opacity)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: rise, matching: find.byType(ImageFiltered)),
      findsOneWidget,
    );
    expect(
      tester.element(find.descendant(of: rise, matching: find.byType(Opacity))),
      same(opacityBefore),
    );
  });
}
