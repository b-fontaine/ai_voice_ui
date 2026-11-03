import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

/// Hôte minimal du mixin [SceneOneShot] : un compteur qui se joue à la demande.
class _Host extends StatefulWidget {
  const _Host({required this.base, required this.onState});

  final Duration base;
  final ValueChanged<_HostState> onState;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host>
    with SingleTickerProviderStateMixin<_Host>, SceneOneShot<_Host> {
  @override
  Duration get oneShotBase => widget.base;

  @override
  void initState() {
    super.initState();
    widget.onState(this);
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

Future<_HostState> _mount(
  WidgetTester tester, {
  bool disabled = false,
  double speed = 1,
  Duration base = SceneMotion.count,
}) async {
  late _HostState state;
  await tester.pumpWidget(
    SceneMotionScope(
      disabled: disabled,
      speed: speed,
      child: _Host(base: base, onState: (s) => state = s),
    ),
  );
  return state;
}

void main() {
  testWidgets('au repos : valeur 0, aucun ticker actif', (tester) async {
    final s = await _mount(tester);
    expect(s.oneShot.value, 0);
    expect(s.oneShot.isAnimating, isFalse);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('play : la durée du jeton est jouée une fois, de 0 à 1', (
    tester,
  ) async {
    final s = await _mount(tester);
    s.playOneShot();
    expect(s.oneShot.duration, SceneMotion.count);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(s.oneShot.value, closeTo(0.5, 0.01));
    await tester.pump(const Duration(milliseconds: 701));
    expect(s.oneShot.value, 1);
    expect(s.oneShot.isAnimating, isFalse);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('la durée est divisée par la vitesse de rejeu', (tester) async {
    final s = await _mount(tester, speed: 2);
    s.playOneShot();
    expect(s.oneShot.duration, const Duration(milliseconds: 700));
  });

  testWidgets('la durée divisée est bornée au plancher', (tester) async {
    final s = await _mount(tester, speed: 8, base: SceneMotion.value);
    s.playOneShot();
    expect(s.oneShot.duration, SceneMotion.floor);
    await tester.pumpAndSettle();
  });

  testWidgets('animations coupées : la lecture finit à 1 sans ticker', (
    tester,
  ) async {
    final s = await _mount(tester, disabled: true);
    s.playOneShot();
    expect(s.oneShot.value, 1);
    expect(s.oneShot.isAnimating, isFalse);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('coupées en cours de lecture : valeur 1 aussitôt', (
    tester,
  ) async {
    late _HostState s;
    Widget host(bool disabled) => SceneMotionScope(
      disabled: disabled,
      child: _Host(base: SceneMotion.count, onState: (v) => s = v),
    );
    await tester.pumpWidget(host(false));
    s.playOneShot();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(s.oneShot.isAnimating, isTrue);
    expect(s.oneShot.value, lessThan(1));

    await tester.pumpWidget(host(true));

    expect(s.oneShot.value, 1);
    expect(s.oneShot.isAnimating, isFalse);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('démontée en cours de lecture : aucun ticker ne fuit', (
    tester,
  ) async {
    final s = await _mount(tester);
    s.playOneShot();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, 1);

    await tester.pumpWidget(const SizedBox());

    expect(tester.takeException(), isNull);
    expect(tester.binding.transientCallbackCount, 0);
  });
}
