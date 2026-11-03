import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

Widget _host(Animation<double> animation, {Interval? interval}) =>
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: DsReveal(
          animation: animation,
          from: const Offset(0, 10),
          interval: interval,
          child: const SizedBox(key: Key('item'), width: 40, height: 20),
        ),
      ),
    );

double _opacity(WidgetTester tester) =>
    tester.widget<FadeTransition>(find.byType(FadeTransition)).opacity.value;

void main() {
  testWidgets('fondu et glissement depuis `from`, en place à 1', (
    tester,
  ) async {
    final controller = AnimationController(
      vsync: tester,
      duration: const Duration(seconds: 1),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller));
    expect(_opacity(tester), 0);
    expect(
      tester.getTopLeft(find.byKey(const Key('item'))),
      const Offset(0, 10),
    );
    controller.value = 0.5;
    await tester.pump();
    expect(_opacity(tester), 0.5);
    expect(
      tester.getTopLeft(find.byKey(const Key('item'))),
      const Offset(0, 5),
    );
    controller.value = 1;
    await tester.pump();
    expect(_opacity(tester), 1);
    expect(tester.getTopLeft(find.byKey(const Key('item'))), Offset.zero);
  });

  testWidgets('avec un intervalle : seule cette part de la cascade joue', (
    tester,
  ) async {
    final controller = AnimationController(
      vsync: tester,
      duration: const Duration(seconds: 1),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(controller, interval: const Interval(0.5, 1)),
    );
    controller.value = 0.25;
    await tester.pump();
    expect(_opacity(tester), 0);
    expect(
      tester.getTopLeft(find.byKey(const Key('item'))),
      const Offset(0, 10),
    );
    controller.value = 0.75;
    await tester.pump();
    expect(_opacity(tester), 0.5);
    expect(
      tester.getTopLeft(find.byKey(const Key('item'))),
      const Offset(0, 5),
    );
    controller.value = 1;
    await tester.pump();
    expect(_opacity(tester), 1);
  });

  testWidgets('aucune reconstruction du parent pendant l\'animation', (
    tester,
  ) async {
    final controller = AnimationController(
      vsync: tester,
      duration: const Duration(seconds: 1),
    );
    addTearDown(controller.dispose);
    var builds = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints box) {
            builds++;
            return DsReveal(
              animation: controller,
              from: const Offset(0, 10),
              child: const SizedBox(width: 40, height: 20),
            );
          },
        ),
      ),
    );
    final int built = builds;
    controller.forward();
    await tester.pumpAndSettle();
    expect(builds, built);
  });
}
