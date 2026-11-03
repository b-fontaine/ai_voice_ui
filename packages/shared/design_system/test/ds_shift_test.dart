import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

/// Hôte : un `LayoutBuilder` (dont on compte les constructions) qui porte un
/// `DsShift` autour d'une cible de 40 × 20 en haut à gauche d'une zone 200 × 100.
class _Host extends StatelessWidget {
  const _Host({
    required this.progress,
    required this.onBuild,
    required this.onTap,
  });

  final Animation<double> progress;
  final VoidCallback onBuild;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 200,
        height: 100,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints box) {
            onBuild();
            return Align(
              alignment: Alignment.topLeft,
              child: DsShift(
                progress: progress,
                offset: const Offset(-12, 8),
                child: _Counting(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onTap,
                    child: const SizedBox(
                      key: Key('target'),
                      width: 40,
                      height: 20,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

void main() {
  late AnimationController controller;
  var builds = 0;
  var taps = 0;

  Future<void> mount(WidgetTester tester) async {
    builds = 0;
    taps = 0;
    controller = AnimationController(
      vsync: tester,
      duration: const Duration(seconds: 1),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _Host(progress: controller, onBuild: () => builds++, onTap: () => taps++),
    );
  }

  testWidgets('translation à la peinture : offset x (1 - progress)', (
    tester,
  ) async {
    await mount(tester);
    // 0 : décalé de tout l'offset ; 1 : en place.
    controller.value = 0;
    await tester.pump();
    expect(
      tester.getTopLeft(find.byKey(const Key('target'))),
      const Offset(-12, 8),
    );
    controller.value = 0.5;
    await tester.pump();
    expect(
      tester.getTopLeft(find.byKey(const Key('target'))),
      const Offset(-6, 4),
    );
    controller.value = 1;
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(const Key('target'))), Offset.zero);
  });

  testWidgets('le clic suit le décalage', (tester) async {
    await mount(tester);
    controller.value = 0; // cible peinte de (-12, 8) à (28, 28)
    await tester.pump();
    // Dans la zone peinte : le clic atteint la cible.
    await tester.tapAt(const Offset(10, 15));
    expect(taps, 1);
    // Dans la position d'origine mais hors de la zone peinte (y < 8).
    await tester.tapAt(const Offset(35, 5));
    expect(taps, 1);
  });

  testWidgets('aucune reconstruction ni remise en page du parent par image', (
    tester,
  ) async {
    await mount(tester);
    final int built = builds;
    final int layouts = _Counting.layouts;
    controller.forward();
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    expect(controller.value, 1);
    expect(builds, built);
    expect(_Counting.layouts, layouts);
    expect(_Counting.paints, greaterThan(5));
  });
}

/// Compte les `performLayout` et les peintures de son enfant : un parent
/// `LayoutBuilder` remis en page à chaque image les ferait augmenter.
class _Counting extends SingleChildRenderObjectWidget {
  const _Counting({required super.child});

  static int layouts = 0;
  static int paints = 0;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderCounting();
}

class _RenderCounting extends RenderProxyBox {
  @override
  void performLayout() {
    _Counting.layouts++;
    super.performLayout();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _Counting.paints++;
    super.paint(context, offset);
  }
}
