import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../acceptance/support/fidelity_harness.dart';

/// Le harnais de la fidélité au design system (spec 019) observe l'écran par
/// des clés et des types de widgets ; ces tests le vérifient sur des widgets
/// synthétiques, pour qu'un scénario d'acceptation ne passe ou n'échoue jamais
/// à cause du harnais.
class _Wipe extends CustomClipper<Rect> {
  _Wipe(this.progress) : super(reclip: progress);

  final Animation<double> progress;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * progress.value, size.height);

  @override
  bool shouldReclip(covariant _Wipe oldClipper) => false;
}

class _Spinner extends CustomPainter {
  _Spinner(this.animation) : super(repaint: animation);

  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      size.center(Offset.zero),
      10 + 10 * animation.value,
      Paint()..color = Colors.cyan,
    );
  }

  @override
  bool shouldRepaint(covariant _Spinner oldDelegate) => false;
}

void main() {
  testWidgets('visibleFraction suit le ClipRect à clipper', (tester) async {
    late AnimationController controller;
    await tester.pumpWidget(
      MaterialApp(
        home: _Host(
          onCreate: (c) => controller = c,
          builder: (c) => ClipRect(
            key: const Key('reveal'),
            clipper: _Wipe(c),
            child: const SizedBox(width: 200, height: 40),
          ),
        ),
      ),
    );
    controller.value = 0.25;
    await tester.pump();
    expect(Fidelity.visibleFraction('reveal'), closeTo(0.25, 0.001));
    controller.value = 1;
    await tester.pump();
    expect(Fidelity.visibleFraction('reveal'), closeTo(1, 0.001));
  });

  testWidgets('blurOf et scaleOf lisent le flou et l échelle des ancêtres', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: Transform.scale(
            scale: 0.985,
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: const SizedBox(
                key: Key('content'),
                width: 100,
                height: 40,
              ),
            ),
          ),
        ),
      ),
    );
    final Finder content = find.byKey(const Key('content'));
    expect(Fidelity.blurOf(content), 4);
    expect(Fidelity.scaleOf(content), closeTo(0.985, 0.0001));

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: ImageFiltered(
            enabled: false,
            imageFilter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: const SizedBox(key: Key('content'), width: 100, height: 40),
          ),
        ),
      ),
    );
    expect(Fidelity.blurOf(content), 0);
    expect(Fidelity.scaleOf(content), 1);
  });

  testWidgets('repaints distingue une boucle d un élément au repos', (
    tester,
  ) async {
    late AnimationController controller;
    await tester.pumpWidget(
      MaterialApp(
        home: _Host(
          onCreate: (c) => c.repeat(),
          onController: (c) => controller = c,
          builder: (c) => Column(
            children: <Widget>[
              RepaintBoundary(
                key: const Key('loop'),
                child: CustomPaint(
                  painter: _Spinner(c),
                  size: const Size(60, 60),
                ),
              ),
              const RepaintBoundary(
                key: Key('rest'),
                child: SizedBox(width: 60, height: 60),
              ),
            ],
          ),
        ),
      ),
    );
    expect(await Fidelity.repaints(tester, 'loop'), isTrue);
    expect(await Fidelity.repaints(tester, 'rest'), isFalse);
    controller.stop();
    await tester.pump();
    expect(await Fidelity.repaints(tester, 'loop'), isFalse);
  });

  testWidgets('couleurs, rayon, bordure, lueur et opacité d un élément', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Opacity(
          opacity: 0.5,
          child: DecoratedBox(
            key: const Key('tile'),
            decoration: BoxDecoration(
              color: const Color(0xFF101731),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x55A58BFF)),
              boxShadow: const <BoxShadow>[
                BoxShadow(color: Color(0x663DE8FF), blurRadius: 28),
              ],
            ),
            child: const SizedBox(width: 80, height: 30),
          ),
        ),
      ),
    );
    final Finder tile = Fidelity.one('tile');
    expect(Fidelity.fillOf(tile), const Color(0xFF101731));
    expect(Fidelity.cornerRadiusOf(tile), 10);
    expect(
      Fidelity.sameTint(Fidelity.borderColorOf(tile)!, const Color(0xFFA58BFF)),
      isTrue,
    );
    expect(Fidelity.shadowsOf(tile), hasLength(1));
    expect(Fidelity.opacity('tile'), 0.5);
  });

  testWidgets('textes, nombres et fonds réels', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Container(
          color: const Color(0xFF18213F),
          child: Text.rich(
            const TextSpan(
              text: '99,57',
              style: TextStyle(fontSize: 76, color: Color(0xFF66739E)),
              children: <InlineSpan>[
                TextSpan(text: ' %', style: TextStyle(fontSize: 36)),
              ],
            ),
            key: const Key('value'),
          ),
        ),
      ),
    );
    expect(Fidelity.textOfKey('value'), '99,57 %');
    expect(Fidelity.numberOf('value'), 99.57);
    expect(Fidelity.styleOf(tester, 'value').fontSize, 76);
    final List<(Element, SpanLeaf)> leaves = Fidelity.visibleLeaves(tester);
    expect(
      leaves.map(((Element, SpanLeaf) l) => l.$2.style.fontSize),
      containsAll(<double>[76, 36]),
    );
    final Element element = leaves.first.$1;
    expect(Fidelity.backgroundsOf(element), contains(const Color(0xFF18213F)));
  });
}

/// Hôte d'un contrôleur d'animation pour les tests du harnais.
class _Host extends StatefulWidget {
  const _Host({required this.builder, this.onCreate, this.onController});

  final Widget Function(AnimationController) builder;
  final void Function(AnimationController)? onCreate;
  final void Function(AnimationController)? onController;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

  @override
  void initState() {
    super.initState();
    widget.onController?.call(_controller);
    widget.onCreate?.call(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_controller);
}
