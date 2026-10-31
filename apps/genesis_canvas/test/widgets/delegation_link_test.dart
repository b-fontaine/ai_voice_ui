import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_canvas/widgets/agents_rail/delegation_link_geometry.dart';
import 'package:genesis_canvas/widgets/agents_rail/delegation_link_painter.dart';
import 'package:shared_design_system/shared_design_system.dart';

/// Tuiles du rail de la démo (1872 px, 96 de haut) : une tuile de 62,4 px de
/// haut, centrée dans le rail, donc 16,8 px libres au-dessus.
const Rect _orchestrator = Rect.fromLTWH(180, 16.8, 300, 62.4);
const Rect _first = Rect.fromLTWH(528, 16.8, 300, 62.4);
const Rect _second = Rect.fromLTWH(844, 16.8, 300, 62.4);
const Rect _third = Rect.fromLTWH(1160, 16.8, 300, 62.4);

DelegationLinkGeometry _to(Rect target) =>
    DelegationLinkGeometry(orchestrator: _orchestrator, target: target);

List<ui.Offset> _sample(Path path, Iterable<double> offsets) {
  final ui.PathMetric metric = path.computeMetrics().single;
  return <ui.Offset>[
    for (final double d in offsets) metric.getTangentForOffset(d)!.position,
  ];
}

/// Image RGBA d'un peintre sur [size], pour comparer des pixels.
Future<Uint8List> _render(CustomPainter painter, Size size) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  painter.paint(ui.Canvas(recorder), size);
  final ui.Image image = await recorder.endRecording().toImage(
    size.width.ceil(),
    size.height.ceil(),
  );
  return (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer
      .asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DelegationLinkGeometry', () {
    test('part au-dessus de la pastille de l\'orchestrateur', () {
      final ui.Offset start = _sample(_to(_first).path, <double>[0]).single;
      expect(start.dx, _orchestrator.left + DelegationLinkGeometry.inset);
      expect(start.dy, lessThan(_orchestrator.top));
    });

    test('arrive au-dessus de la pastille de l\'agent', () {
      final DelegationLinkGeometry link = _to(_first);
      final ui.Offset end = _sample(link.path, <double>[link.length]).single;
      expect(end.dx, _first.left + DelegationLinkGeometry.inset);
      expect(end.dy, lessThan(_first.top));
    });

    test('l\'arc reste au-dessus des tuiles, dans les 16,8 px libres', () {
      for (final Rect target in <Rect>[_first, _second, _third]) {
        final Rect ink = _to(target).path
            .getBounds()
            .inflate(DelegationLinkGeometry.strokeWidth / 2);
        expect(ink.bottom, lessThanOrEqualTo(_orchestrator.top));
        expect(ink.bottom, lessThanOrEqualTo(target.top));
        expect(ink.top, greaterThanOrEqualTo(0), reason: 'dans le rail');
      }
    });

    test('la tuile la plus éloignée passe au-dessus des tuiles du milieu', () {
      final Rect ink = _to(_third).path
          .getBounds()
          .inflate(DelegationLinkGeometry.strokeWidth / 2);
      for (final Rect middle in <Rect>[_first, _second]) {
        expect(ink.left, lessThan(middle.left));
        expect(ink.right, greaterThan(middle.right));
        expect(ink.bottom, lessThanOrEqualTo(middle.top));
      }
    });

    test('l\'épaisseur du trait est d\'au moins 3 px', () {
      expect(DelegationLinkGeometry.strokeWidth, greaterThanOrEqualTo(3));
    });

    test('tous les liens partagent le même préfixe de tracé', () {
      final List<double> offsets = <double>[for (double d = 0; d <= 12; d++) d];
      final List<ui.Offset> reference = _sample(_to(_first).path, offsets);
      expect(_sample(_to(_second).path, offsets), reference);
      expect(_sample(_to(_third).path, offsets), reference);
    });

    test('le chemin est calculé une fois par géométrie', () {
      final DelegationLinkGeometry link = _to(_second);
      expect(identical(link.path, link.path), isTrue);
      expect(identical(link.metric, link.metric), isTrue);
      expect(link.length, link.metric.length);
    });

    test('deux géométries de mêmes rectangles sont égales', () {
      expect(_to(_first), _to(_first));
      expect(_to(_first).hashCode, _to(_first).hashCode);
      expect(_to(_first), isNot(_to(_second)));
    });

    test(
      'un agent trop proche pour les coins arrondis ne casse pas le tracé',
      () {
        final Rect near = _orchestrator.shift(const Offset(4, 0));
        final DelegationLinkGeometry link = DelegationLinkGeometry(
          orchestrator: _orchestrator,
          target: near,
        );
        expect(link.length, greaterThan(0));
        expect(link.path.getBounds().isFinite, isTrue);
      },
    );
  });

  group('DelegationLinkPainter', () {
    const SceneTheme theme = SceneTheme.dark();
    const Size area = Size(1600, 96);
    final AnimationController controller = AnimationController(
      vsync: const TestVSync(),
    );
    tearDownAll(controller.dispose);

    DelegationLinkPainter painter(
      List<DelegationLinkGeometry> links, {
      Color? color,
      Animation<double>? phase,
    }) => DelegationLinkPainter(
      links: links,
      color: color ?? theme.accent,
      phase: phase ?? const AlwaysStoppedAnimation<double>(0),
    );

    Set<int> inkRows(Uint8List pixels, int width) {
      final Set<int> rows = <int>{};
      for (int i = 3; i < pixels.length; i += 4) {
        if (pixels[i] != 0) rows.add((i ~/ 4) ~/ width);
      }
      return rows;
    }

    test('dessine avec la couleur reçue, dans les 16,8 px au-dessus', () async {
      final Uint8List pixels = await _render(
        painter(<DelegationLinkGeometry>[_to(_third)]),
        area,
      );
      expect(pixels.any((b) => b != 0), isTrue);
      final Set<int> rows = inkRows(pixels, 1600);
      expect(rows.reduce((a, b) => a > b ? a : b), lessThan(17));
      // Un pixel plein porte exactement la couleur du thème de scène.
      final ui.Color c = theme.accent;
      bool found = false;
      for (int i = 0; i < pixels.length && !found; i += 4) {
        found =
            pixels[i + 3] == 255 &&
            pixels[i] == (c.r * 255).round() &&
            pixels[i + 1] == (c.g * 255).round() &&
            pixels[i + 2] == (c.b * 255).round();
      }
      expect(found, isTrue);
    });

    test('des pointillés : l\'horizontale alterne trait et vide', () async {
      final Uint8List pixels = await _render(
        painter(<DelegationLinkGeometry>[_to(_third)]),
        area,
      );
      final Set<int> rows = inkRows(pixels, 1600);
      final int lane = rows.reduce((a, b) => a < b ? a : b) + 1;
      final List<bool> ink = <bool>[
        for (int x = 600; x < 1000; x++) pixels[(lane * 1600 + x) * 4 + 3] != 0,
      ];
      expect(ink, contains(true));
      expect(ink, contains(false));
    });

    test(
      'seule la phase change les pixels, d\'une période à l\'autre',
      () async {
        final List<DelegationLinkGeometry> links = <DelegationLinkGeometry>[
          _to(_third),
        ];
        controller.value = 0;
        final Uint8List a = await _render(
          painter(links, phase: controller),
          area,
        );
        controller.value = 0.25;
        final Uint8List b = await _render(
          painter(links, phase: controller),
          area,
        );
        controller.value = 1;
        final Uint8List c = await _render(
          painter(links, phase: controller),
          area,
        );
        expect(b, isNot(a), reason: 'les pointillés défilent');
        expect(c, a, reason: 'une boucle revient à son point de départ');
      },
    );

    test('plusieurs liens : un tracé par lien, préfixe confondu', () async {
      final Uint8List one = await _render(
        painter(<DelegationLinkGeometry>[_to(_first)]),
        area,
      );
      final Uint8List two = await _render(
        painter(<DelegationLinkGeometry>[_to(_first), _to(_second)]),
        area,
      );
      expect(two, isNot(one));
      // Le tracé du premier lien reste entier sous le second.
      for (int i = 3; i < one.length; i += 4) {
        if (one[i] != 0) expect(two[i], greaterThan(0));
      }
    });

    test('sans lien, rien n\'est dessiné', () async {
      final Uint8List pixels = await _render(
        painter(const <DelegationLinkGeometry>[]),
        area,
      );
      expect(pixels.every((b) => b == 0), isTrue);
    });

    test('shouldRepaint : seulement si les liens ou la couleur changent', () {
      final DelegationLinkPainter base = painter(<DelegationLinkGeometry>[
        _to(_first),
      ]);
      expect(
        base.shouldRepaint(painter(<DelegationLinkGeometry>[_to(_first)])),
        isFalse,
      );
      expect(
        base.shouldRepaint(
          painter(<DelegationLinkGeometry>[_to(_first), _to(_second)]),
        ),
        isTrue,
      );
      expect(
        base.shouldRepaint(
          painter(<DelegationLinkGeometry>[
            _to(_first),
          ], color: theme.okForeground),
        ),
        isTrue,
      );
    });

    test('contraste de la couleur du thème avec le fond : au moins 3:1', () {
      double lum(Color c) {
        double ch(double v) => v <= 0.03928
            ? v / 12.92
            : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
        return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
      }

      final double a = lum(theme.accent);
      final double b = lum(theme.background);
      final double ratio =
          (a > b ? a + 0.05 : b + 0.05) / (a > b ? b + 0.05 : a + 0.05);
      expect(ratio, greaterThanOrEqualTo(3));
    });
  });
}
