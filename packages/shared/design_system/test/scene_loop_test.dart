import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

/// Hôte minimal du mixin [SceneLoop] : une boucle de période [SceneMotion.blink].
class _Host extends StatefulWidget {
  const _Host({
    required this.base,
    required this.onState,
    this.active = true,
    this.reverse = false,
  });

  final Duration base;
  final bool active;
  final bool reverse;
  final ValueChanged<_HostState> onState;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host>
    with SingleTickerProviderStateMixin<_Host>, SceneLoop<_Host> {
  @override
  Duration get loopBase => widget.base;

  @override
  double get loopRestValue => 0.7;

  @override
  bool get loopActive => widget.active;

  @override
  bool get loopReverse => widget.reverse;

  @override
  void initState() {
    super.initState();
    widget.onState(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncLoop();
  }

  @override
  void didUpdateWidget(_Host oldWidget) {
    super.didUpdateWidget(oldWidget);
    syncLoop();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

Future<_HostState> _mount(
  WidgetTester tester, {
  bool disabled = false,
  double speed = 1,
  Duration base = SceneMotion.blink,
  bool active = true,
  bool reverse = false,
}) async {
  late _HostState state;
  await _pump(tester, (s) => state = s, disabled, speed, base, active, reverse);
  return state;
}

Future<void> _pump(
  WidgetTester tester,
  ValueChanged<_HostState> onState,
  bool disabled,
  double speed,
  Duration base,
  bool active,
  bool reverse,
) async {
  await tester.pumpWidget(
    SceneMotionScope(
      disabled: disabled,
      speed: speed,
      child: _Host(
        base: base,
        active: active,
        reverse: reverse,
        onState: onState,
      ),
    ),
  );
}

/// Reconstruit l'hôte déjà monté avec d'autres réglages.
Future<void> _rebuild(
  WidgetTester tester, {
  bool disabled = false,
  double speed = 1,
  Duration base = SceneMotion.blink,
  bool active = true,
}) => _pump(tester, (_) {}, disabled, speed, base, active, false);

void main() {
  testWidgets('la boucle tourne sur la période du jeton', (tester) async {
    final s = await _mount(tester);
    expect(s.loop.isAnimating, isTrue);
    expect(s.loop.duration, SceneMotion.blink);
    await tester.pump(SceneMotion.blink ~/ 4);
    expect(s.loop.value, closeTo(0.25, 0.01));
  });

  testWidgets('animations coupées : phase de repos, aucun ticker actif', (
    tester,
  ) async {
    final s = await _mount(tester, disabled: true);
    expect(s.loop.value, 0.7);
    expect(s.loop.isAnimating, isFalse);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('une reconstruction à période égale ne relance pas la boucle', (
    tester,
  ) async {
    final s = await _mount(tester);
    await tester.pump(SceneMotion.blink ~/ 3);
    final double before = s.loop.value;
    await _rebuild(tester); // même période : simple reconstruction
    expect(s.loop.value, before);
    expect(s.loop.isAnimating, isTrue);
  });

  testWidgets('un changement de période relance la boucle sur la nouvelle', (
    tester,
  ) async {
    final s = await _mount(tester);
    await tester.pump(SceneMotion.blink ~/ 3);
    await _rebuild(tester, base: const Duration(seconds: 3));
    expect(s.loop.duration, const Duration(seconds: 3));
    expect(s.loop.isAnimating, isTrue);
  });

  testWidgets('un changement de vitesse met la période à l’échelle', (
    tester,
  ) async {
    final s = await _mount(tester);
    await _rebuild(tester, speed: 2);
    expect(s.loop.duration, SceneMotion.blink ~/ 2);
    expect(s.loop.isAnimating, isTrue);
  });

  testWidgets('animations coupées puis rétablies : la boucle repart', (
    tester,
  ) async {
    final s = await _mount(tester);
    await _rebuild(tester, disabled: true);
    expect(s.loop.isAnimating, isFalse);
    expect(s.loop.value, 0.7);
    await _rebuild(tester);
    expect(s.loop.isAnimating, isTrue);
    expect(s.loop.duration, SceneMotion.blink);
  });

  testWidgets('loopActive faux : arrêt à la phase de repos', (tester) async {
    final s = await _mount(tester);
    await tester.pump(SceneMotion.blink ~/ 3);
    await _rebuild(tester, active: false);
    expect(s.loop.isAnimating, isFalse);
    expect(s.loop.value, 0.7);
    expect(tester.binding.transientCallbackCount, 0);
    await _rebuild(tester);
    expect(s.loop.isAnimating, isTrue);
  });

  testWidgets('loopReverse : la phase va et vient', (tester) async {
    final s = await _mount(tester, reverse: true);
    await tester.pump(SceneMotion.blink * 3 ~/ 2);
    expect(s.loop.value, closeTo(0.5, 0.02));
    expect(s.loop.status, AnimationStatus.reverse);
  });

  testWidgets('aucun ticker restant après dispose', (tester) async {
    final s = await _mount(tester);
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pumpWidget(const SizedBox());
    expect(tester.binding.transientCallbackCount, 0);
    expect(() => s.loop.value, returnsNormally);
    expect(s.loop.isAnimating, isFalse);
  });
}
