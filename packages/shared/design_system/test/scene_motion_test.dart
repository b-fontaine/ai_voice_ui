import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

void main() {
  group('SceneMotion', () {
    test('porte les durées et la courbe de pdr-0075 D3', () {
      expect(SceneMotion.appear, const Duration(milliseconds: 200));
      expect(SceneMotion.value, const Duration(milliseconds: 150));
      expect(SceneMotion.status, const Duration(milliseconds: 400));
      expect(SceneMotion.translation, 8);
      expect(SceneMotion.floor, const Duration(milliseconds: 60));
      expect(SceneMotion.curve, Curves.easeOutCubic);
    });

    test('la vitesse 1 ne change pas la durée', () {
      expect(
        SceneMotion.scaled(SceneMotion.appear, speed: 1),
        SceneMotion.appear,
      );
    });

    test('la vitesse 2 divise la durée', () {
      expect(
        SceneMotion.scaled(SceneMotion.appear, speed: 2),
        const Duration(milliseconds: 100),
      );
    });

    test('la durée est bornée au plancher de 60 ms', () {
      expect(
        SceneMotion.scaled(SceneMotion.value, speed: 8),
        SceneMotion.floor,
      );
    });

    test('une durée nulle reste nulle', () {
      expect(SceneMotion.scaled(Duration.zero, speed: 4), Duration.zero);
    });

    test('une vitesse invalide retombe sur la durée de base', () {
      expect(
        SceneMotion.scaled(SceneMotion.appear, speed: 0),
        SceneMotion.appear,
      );
    });
  });

  group('SceneMotionScope', () {
    testWidgets('sans scope : animations actives, vitesse 1', (tester) async {
      late SceneMotionScope seen;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            seen = SceneMotionScope.of(context);
            return const SizedBox();
          },
        ),
      );
      expect(seen.disabled, isFalse);
      expect(seen.speed, 1);
    });

    testWidgets('un scope propage disabled et speed', (tester) async {
      late SceneMotionScope seen;
      await tester.pumpWidget(
        SceneMotionScope(
          disabled: true,
          speed: 2,
          child: Builder(
            builder: (context) {
              seen = SceneMotionScope.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen.disabled, isTrue);
      expect(seen.speed, 2);
    });

    testWidgets('duration : nulle si désactivé, sinon mise à l\'échelle', (
      tester,
    ) async {
      late BuildContext ctx;
      Widget host({required bool disabled, required double speed}) =>
          SceneMotionScope(
            disabled: disabled,
            speed: speed,
            child: Builder(
              builder: (context) {
                ctx = context;
                return const SizedBox();
              },
            ),
          );
      await tester.pumpWidget(host(disabled: true, speed: 2));
      expect(
        SceneMotionScope.of(ctx).durationFor(SceneMotion.appear),
        Duration.zero,
      );
      await tester.pumpWidget(host(disabled: false, speed: 2));
      expect(
        SceneMotionScope.of(ctx).durationFor(SceneMotion.appear),
        const Duration(milliseconds: 100),
      );
    });

    testWidgets('notifie les dépendants quand speed change', (tester) async {
      int builds = 0;
      Widget host(double speed) => SceneMotionScope(
        disabled: false,
        speed: speed,
        child: Builder(
          builder: (context) {
            SceneMotionScope.of(context);
            builds++;
            return const SizedBox();
          },
        ),
      );
      await tester.pumpWidget(host(1));
      await tester.pumpWidget(host(2));
      expect(builds, 2);
    });
  });
}
