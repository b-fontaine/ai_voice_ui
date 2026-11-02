import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

void main() {
  group('SceneMotion', () {
    test('porte les durées et la courbe de pdr-0084 U2', () {
      expect(SceneMotion.appear, const Duration(milliseconds: 480));
      expect(SceneMotion.value, const Duration(milliseconds: 160));
      expect(SceneMotion.status, const Duration(milliseconds: 400));
      expect(SceneMotion.translation, 10);
      expect(SceneMotion.link, const Duration(milliseconds: 1200));
      expect(SceneMotion.beacon, const Duration(milliseconds: 1600));
      expect(SceneMotion.skeleton, const Duration(milliseconds: 1200));
      expect(SceneMotion.floor, const Duration(milliseconds: 60));
    });

    test('la courbe est Cubic(.2, .8, .2, 1)', () {
      final Curve curve = SceneMotion.curve;
      expect(curve, isA<Cubic>());
      final Cubic cubic = curve as Cubic;
      expect(
        <double>[cubic.a, cubic.b, cubic.c, cubic.d],
        <double>[0.2, 0.8, 0.2, 1],
      );
      expect(curve.transform(0), 0);
      expect(curve.transform(1), 1);
      // Départ vif, arrivée douce : déjà au-delà de 90 % à mi-parcours.
      expect(curve.transform(0.5), greaterThan(0.9));
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
        const Duration(milliseconds: 240),
      );
      expect(
        SceneMotion.scaled(SceneMotion.status, speed: 2),
        const Duration(milliseconds: 200),
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
        const Duration(milliseconds: 240),
      );
    });

    group('play', () {
      Future<AnimationController> run(
        WidgetTester tester, {
        required bool disabled,
        required double speed,
        required Duration base,
      }) async {
        late AnimationController controller;
        await tester.pumpWidget(
          SceneMotionScope(
            disabled: disabled,
            speed: speed,
            child: _Player(base: base, onController: (c) => controller = c),
          ),
        );
        return controller;
      }

      testWidgets('durée nulle : valeur 1 sans animation', (tester) async {
        final c = await run(
          tester,
          disabled: true,
          speed: 1,
          base: SceneMotion.appear,
        );
        expect(c.value, 1);
        expect(c.isAnimating, isFalse);
        expect(c.duration, Duration.zero);
      });

      testWidgets('vitesse 2 : durée divisée, animation depuis 0', (
        tester,
      ) async {
        final c = await run(
          tester,
          disabled: false,
          speed: 2,
          base: SceneMotion.appear,
        );
        expect(c.duration, const Duration(milliseconds: 240));
        expect(c.value, 0);
        expect(c.isAnimating, isTrue);
        await tester.pump(const Duration(milliseconds: 240));
        await tester.pump(const Duration(milliseconds: 240));
        expect(c.value, 1);
      });

      testWidgets(
        'disabled en cours de route : la lecture se termine aussitôt',
        (tester) async {
          late AnimationController c;
          Widget host(bool disabled) => SceneMotionScope(
            disabled: disabled,
            child: _Player(
              base: SceneMotion.appear,
              onController: (controller) => c = controller,
            ),
          );
          await tester.pumpWidget(host(false));
          await tester.pump(const Duration(milliseconds: 100));
          expect(c.isAnimating, isTrue);
          expect(c.value, lessThan(1));

          await tester.pumpWidget(host(true));
          expect(c.value, 1);
          expect(c.isAnimating, isFalse);
          expect(tester.binding.transientCallbackCount, 0);
        },
      );

      testWidgets('plancher de 60 ms', (tester) async {
        final c = await run(
          tester,
          disabled: false,
          speed: 8,
          base: SceneMotion.value,
        );
        expect(c.duration, SceneMotion.floor);
        await tester.pumpAndSettle();
      });
    });

    group('loop', () {
      Future<AnimationController> run(
        WidgetTester tester, {
        required bool disabled,
        double speed = 1,
      }) async {
        late AnimationController controller;
        await tester.pumpWidget(
          SceneMotionScope(
            disabled: disabled,
            speed: speed,
            child: _Looper(
              base: SceneMotion.link,
              onController: (c) => controller = c,
            ),
          ),
        );
        return controller;
      }

      testWidgets('animations actives : boucle sur la période du jeton', (
        tester,
      ) async {
        final c = await run(tester, disabled: false);
        expect(c.duration, SceneMotion.link);
        expect(c.isAnimating, isTrue);
        await tester.pump(const Duration(milliseconds: 600));
        expect(c.value, closeTo(0.5, 0.01));
        // Une boucle repart de 0 au lieu de s'arrêter à 1.
        await tester.pump(const Duration(milliseconds: 700));
        expect(c.value, closeTo(0.0833, 0.01));
        expect(c.isAnimating, isTrue);
      });

      testWidgets('vitesse 2 : période divisée', (tester) async {
        final c = await run(tester, disabled: false, speed: 2);
        expect(c.duration, const Duration(milliseconds: 600));
        await tester.pump(const Duration(milliseconds: 300));
        expect(c.value, closeTo(0.5, 0.01));
      });

      testWidgets('reverse : la phase repart en sens inverse après 1', (
        tester,
      ) async {
        late AnimationController c;
        await tester.pumpWidget(
          SceneMotionScope(
            child: _Looper(
              base: SceneMotion.skeleton,
              reverse: true,
              onController: (controller) => c = controller,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 1200));
        expect(c.value, closeTo(1, 0.01));
        await tester.pump(const Duration(milliseconds: 600));
        expect(c.value, closeTo(0.5, 0.01), reason: 'retour vers 0');
        expect(c.isAnimating, isTrue);
      });

      testWidgets('disabled : contrôleur arrêté, phase fixe', (tester) async {
        final c = await run(tester, disabled: true);
        expect(c.isAnimating, isFalse);
        final double phase = c.value;
        await tester.pump(const Duration(seconds: 5));
        expect(c.value, phase);
        expect(c.isAnimating, isFalse);
        expect(tester.binding.hasScheduledFrame, isFalse);
      });

      testWidgets(
        'bascule de disabled en cours de route : arrêt, puis reprise',
        (tester) async {
          late AnimationController c;
          Widget host(bool disabled) => SceneMotionScope(
            disabled: disabled,
            child: _Looper(
              base: SceneMotion.link,
              onController: (controller) => c = controller,
            ),
          );
          await tester.pumpWidget(host(false));
          await tester.pump(const Duration(milliseconds: 300));
          expect(c.isAnimating, isTrue);
          await tester.pumpWidget(host(true));
          expect(c.isAnimating, isFalse);
          final double frozen = c.value;
          await tester.pump(const Duration(seconds: 2));
          expect(c.value, frozen);
          await tester.pumpWidget(host(false));
          expect(c.isAnimating, isTrue);
          await tester.pump(const Duration(milliseconds: 300));
          expect(c.value, isNot(frozen));
        },
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

/// Joue un contrôleur via [SceneMotionScope.play] au premier rendu.
class _Player extends StatefulWidget {
  const _Player({required this.base, required this.onController});

  final Duration base;
  final void Function(AnimationController) onController;

  @override
  State<_Player> createState() => _PlayerState();
}

class _PlayerState extends State<_Player> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      SceneMotionScope.completeIfDisabled(context, _controller);
      return;
    }
    _started = true;
    SceneMotionScope.play(context, _controller, widget.base);
    widget.onController(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

/// Boucle un contrôleur via [SceneMotionScope.loop] à chaque changement de
/// dépendance.
class _Looper extends StatefulWidget {
  const _Looper({
    required this.base,
    required this.onController,
    this.reverse = false,
  });

  final Duration base;
  final bool reverse;
  final void Function(AnimationController) onController;

  @override
  State<_Looper> createState() => _LooperState();
}

class _LooperState extends State<_Looper> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);

  @override
  void initState() {
    super.initState();
    widget.onController(_controller);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    SceneMotionScope.loop(
      context,
      _controller,
      widget.base,
      reverse: widget.reverse,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}
