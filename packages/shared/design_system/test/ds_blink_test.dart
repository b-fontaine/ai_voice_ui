import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

/// Clignotement en créneaux (`gc-blink`, `steps(2)`, 019 T34, pdr-0088 F9).
Widget _host({
  bool disabled = false,
  double speed = 1,
  Duration period = SceneMotion.blink,
  Widget child = const SizedBox.square(key: Key('dot'), dimension: 8),
}) => Directionality(
  textDirection: TextDirection.ltr,
  child: SceneMotionScope(
    disabled: disabled,
    speed: speed,
    child: DsBlink(period: period, child: child),
  ),
);

double _opacity(WidgetTester tester) =>
    tester.widget<FadeTransition>(find.byType(FadeTransition)).opacity.value;

void main() {
  testWidgets('plein une demi-période, à 0,2 l\'autre demi-période', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    expect(_opacity(tester), 1);
    await tester.pump(const Duration(milliseconds: 400));
    expect(_opacity(tester), 1);
    await tester.pump(const Duration(milliseconds: 200));
    expect(_opacity(tester), 0.2);
    await tester.pump(const Duration(milliseconds: 450));
    expect(_opacity(tester), 1, reason: 'nouvelle période');
  });

  testWidgets('la vitesse de rejeu raccourcit la période', (tester) async {
    await tester.pumpWidget(_host(speed: 2));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_opacity(tester), 0.2);
  });

  testWidgets('un RepaintBoundary propre et un seul Ticker', (tester) async {
    await tester.pumpWidget(_host());
    expect(
      find.ancestor(
        of: find.byKey(const Key('dot')),
        matching: find.byType(RepaintBoundary),
      ),
      findsWidgets,
    );
    expect(
      find.descendant(
        of: find.byType(DsBlink),
        matching: find.byType(RepaintBoundary),
      ),
      findsOneWidget,
    );
    expect(tester.binding.transientCallbackCount, 1);
  });

  testWidgets('une reconstruction ne relance pas la boucle', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(milliseconds: 600));
    expect(_opacity(tester), 0.2);
    await tester.pumpWidget(
      _host(child: const SizedBox.square(key: Key('dot'), dimension: 9)),
    );
    expect(_opacity(tester), 0.2, reason: 'phase conservée');
  });

  testWidgets('animations coupées : plein, aucune boucle, même en cours de '
      'route', (tester) async {
    await tester.pumpWidget(_host(disabled: true));
    expect(_opacity(tester), 1);
    expect(tester.binding.transientCallbackCount, 0);

    await tester.pumpWidget(_host());
    await tester.pump(const Duration(milliseconds: 600));
    expect(_opacity(tester), 0.2);
    await tester.pumpWidget(_host(disabled: true));
    expect(_opacity(tester), 1, reason: 'jamais figé à demi-teinte');
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('un changement de période relance la boucle à la nouvelle '
      'période', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpWidget(_host(period: const Duration(seconds: 2)));
    await tester.pump(const Duration(milliseconds: 1100));
    expect(_opacity(tester), 0.2);
  });
}
