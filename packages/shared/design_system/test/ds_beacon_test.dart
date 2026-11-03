import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

/// Point qui bat (`gc-beacon`, 019 T34) : halo qui s'étend, point plein
/// dessiné par le widget ou par l'appelant, phase de repos sans halo.
Widget _host({
  bool disabled = false,
  Duration period = SceneMotion.beacon,
  Widget? child,
}) => Directionality(
  textDirection: TextDirection.ltr,
  child: SceneMotionScope(
    disabled: disabled,
    child: DsBeacon(
      color: const Color(0xFF00FF00),
      size: 8,
      period: period,
      child: child,
    ),
  ),
);

List<RecordedInvocation> _circles(WidgetTester tester) {
  final RenderCustomPaint render = tester.renderObject<RenderCustomPaint>(
    find.descendant(
      of: find.byType(DsBeacon),
      matching: find.byType(CustomPaint),
    ),
  );
  final TestRecordingCanvas canvas = TestRecordingCanvas();
  render.painter!.paint(canvas, const Size.square(8));
  return canvas.invocations
      .where((RecordedInvocation c) => c.invocation.memberName == #drawCircle)
      .toList();
}

void main() {
  testWidgets('sans enfant : point plein, puis halo qui s\'étend', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    expect(_circles(tester), hasLength(1), reason: 'point seul au départ');
    await tester.pump(const Duration(milliseconds: 600));
    expect(_circles(tester), hasLength(2), reason: 'halo et point');
  });

  testWidgets('avec enfant : seul le halo est dessiné, l\'enfant reste', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(child: const SizedBox.square(key: Key('dot'), dimension: 8)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(_circles(tester), hasLength(1), reason: 'halo seul');
    expect(find.byKey(const Key('dot')), findsOneWidget);
  });

  testWidgets('la période est réglable : le halo disparaît après 70 % de '
      'la période', (tester) async {
    await tester.pumpWidget(_host(period: const Duration(milliseconds: 1200)));
    await tester.pump(const Duration(milliseconds: 500));
    expect(_circles(tester), hasLength(2), reason: 'à 42 % : halo');
    await tester.pump(const Duration(milliseconds: 400));
    expect(_circles(tester), hasLength(1), reason: 'à 75 % : point seul');
    // Avec la période par défaut (1,6 s), 900 ms n'est qu'à 56 %.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(milliseconds: 900));
    expect(_circles(tester), hasLength(2));
  });

  testWidgets('un seul Ticker, dans un RepaintBoundary propre', (tester) async {
    await tester.pumpWidget(_host());
    expect(tester.binding.transientCallbackCount, 1);
    expect(
      find.descendant(
        of: find.byType(DsBeacon),
        matching: find.byType(RepaintBoundary),
      ),
      findsOneWidget,
    );
  });

  testWidgets('animations coupées : point seul, sans halo ni boucle', (
    tester,
  ) async {
    await tester.pumpWidget(_host(disabled: true));
    expect(_circles(tester), hasLength(1));
    await tester.pump(const Duration(milliseconds: 600));
    expect(_circles(tester), hasLength(1));
    expect(tester.binding.transientCallbackCount, 0);
  });
}
