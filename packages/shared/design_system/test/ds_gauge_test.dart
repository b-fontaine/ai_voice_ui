import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

const SceneTheme _theme = SceneTheme.dark();
const DsGaugeKeys _keys = DsGaugeKeys(
  track: Key('g-track'),
  fill: Key('g-fill'),
  mark: Key('g-mark'),
  markLabel: Key('g-mark-label'),
  reference: Key('g-ref'),
  referenceLabel: Key('g-ref-label'),
);

Widget _host(DsGauge gauge, {bool disabled = false, double width = 400}) =>
    MaterialApp(
      theme: ThemeData(extensions: const <ThemeExtension<dynamic>>[_theme]),
      home: SceneMotionScope(
        disabled: disabled,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, child: gauge),
        ),
      ),
    );

DsGauge _gauge({
  double fill = 0.43,
  Color? color,
  double? mark = 0.5,
  String? markLabel = 'seuil 99,50',
  double? reference = 0.71,
  String? referenceLabel = '3.3',
  bool settled = false,
}) => DsGauge(
  fill: fill,
  fillColor: color ?? _theme.blockingForeground,
  mark: mark,
  markLabel: markLabel,
  reference: reference,
  referenceLabel: referenceLabel,
  settled: settled,
  keys: _keys,
);

Rect _r(WidgetTester t, String key) => t.getRect(find.byKey(Key(key)));

void main() {
  testWidgets('piste de 8 px en surface-300, rayon 4', (tester) async {
    await tester.pumpWidget(_host(_gauge(), disabled: true));
    expect(_r(tester, 'g-track').height, 8);
    expect(_r(tester, 'g-track').width, 400);
    final DecoratedBox track = tester.widget(find.byKey(const Key('g-track')));
    final BoxDecoration d = track.decoration as BoxDecoration;
    expect(d.color, _theme.surface300);
    expect(d.borderRadius, BorderRadius.circular(4));
  });

  testWidgets('remplissage : fraction de la piste, couleur donnée', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_gauge(), disabled: true));
    expect(_r(tester, 'g-fill').width, closeTo(400 * 0.43, 0.01));
    expect(_r(tester, 'g-fill').left, _r(tester, 'g-track').left);
    expect(_r(tester, 'g-fill').height, 8);
    final DecoratedBox fill = tester.widget(find.byKey(const Key('g-fill')));
    expect((fill.decoration as BoxDecoration).color, _theme.blockingForeground);
  });

  testWidgets('marque de seuil : 2 px en ink, dépasse la piste de 6 px', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_gauge(), disabled: true));
    final Rect mark = _r(tester, 'g-mark');
    final Rect track = _r(tester, 'g-track');
    expect(mark.width, 2);
    expect(mark.center.dx, closeTo(track.left + 200, 0.01));
    expect(track.top - mark.top, 6);
    expect(mark.bottom - track.bottom, 6);
    final DecoratedBox box = tester.widget(find.byKey(const Key('g-mark')));
    expect((box.decoration as BoxDecoration).color, _theme.textPrimary);
  });

  testWidgets('étiquette de marque : au-dessus, ink-muted, 11 à 12 px', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_gauge(), disabled: true));
    final Rect label = _r(tester, 'g-mark-label');
    expect(label.bottom, lessThanOrEqualTo(_r(tester, 'g-mark').top));
    expect(label.center.dx, closeTo(_r(tester, 'g-mark').center.dx, 0.5));
    final Text text = tester.widget(find.byKey(const Key('g-mark-label')));
    expect(text.data, 'seuil 99,50');
    expect(text.style?.color, _theme.textSecondary);
    expect(text.style?.fontSize, inInclusiveRange(11, 12));
  });

  testWidgets('repère : 2 px en baseline, dépasse de 3 px, étiquette dessous', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_gauge(), disabled: true));
    final Rect ref = _r(tester, 'g-ref');
    final Rect track = _r(tester, 'g-track');
    expect(ref.width, 2);
    expect(ref.center.dx, closeTo(track.left + 400 * 0.71, 0.01));
    expect(track.top - ref.top, 3);
    expect(ref.bottom - track.bottom, 3);
    final DecoratedBox box = tester.widget(find.byKey(const Key('g-ref')));
    expect((box.decoration as BoxDecoration).color, _theme.chartOther);
    final Rect label = _r(tester, 'g-ref-label');
    expect(label.top, greaterThanOrEqualTo(ref.bottom));
    expect(label.center.dx, closeTo(ref.center.dx, 0.5));
    final Text text = tester.widget(find.byKey(const Key('g-ref-label')));
    expect(text.data, '3.3');
    expect(text.style?.color, _theme.textSecondary);
  });

  testWidgets('sans marque ni repère : aucun des deux n\'est peint', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        _gauge(
          mark: null,
          markLabel: null,
          reference: null,
          referenceLabel: null,
        ),
        disabled: true,
      ),
    );
    expect(find.byKey(const Key('g-mark')), findsNothing);
    expect(find.byKey(const Key('g-mark-label')), findsNothing);
    expect(find.byKey(const Key('g-ref')), findsNothing);
    expect(find.byKey(const Key('g-ref-label')), findsNothing);
    expect(find.byKey(const Key('g-track')), findsOneWidget);
  });

  testWidgets('une étiquette au bord reste dans la largeur de la jauge', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(_gauge(mark: 1, reference: 0), disabled: true),
    );
    final Rect track = _r(tester, 'g-track');
    expect(_r(tester, 'g-mark-label').right, lessThanOrEqualTo(track.right));
    expect(_r(tester, 'g-ref-label').left, greaterThanOrEqualTo(track.left));
    expect(tester.takeException(), isNull);
  });

  testWidgets('remplissage animé en 1,4 s (SceneMotion.gauge)', (tester) async {
    await tester.pumpWidget(_host(_gauge()));
    expect(_r(tester, 'g-fill').width, 0);
    await tester.pump(const Duration(milliseconds: 100));
    final double early = _r(tester, 'g-fill').width;
    expect(early, greaterThan(0));
    expect(early, lessThan(400 * 0.43));
    await tester.pump(SceneMotion.gauge - const Duration(milliseconds: 100));
    expect(_r(tester, 'g-fill').width, closeTo(400 * 0.43, 0.01));
    await tester.pump(const Duration(milliseconds: 20));
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('animations coupées : état final aussitôt', (tester) async {
    await tester.pumpWidget(_host(_gauge(), disabled: true));
    expect(_r(tester, 'g-fill').width, closeTo(400 * 0.43, 0.01));
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('surface restaurée (settled) : en place sans animation', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_gauge(settled: true)));
    expect(_r(tester, 'g-fill').width, closeTo(400 * 0.43, 0.01));
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('un nouveau remplissage rejoue l\'animation depuis le vide', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_gauge(fill: 0.57)));
    await tester.pump(SceneMotion.gauge);
    expect(_r(tester, 'g-fill').width, closeTo(400 * 0.57, 0.01));
    await tester.pumpWidget(_host(_gauge(fill: 0.43)));
    expect(_r(tester, 'g-fill').width, 0);
    await tester.pump(SceneMotion.gauge);
    expect(_r(tester, 'g-fill').width, closeTo(400 * 0.43, 0.01));
  });

  testWidgets('la jauge a son RepaintBoundary local', (tester) async {
    await tester.pumpWidget(_host(_gauge(), disabled: true));
    expect(
      find.descendant(
        of: find.byType(DsGauge),
        matching: find.byType(RepaintBoundary),
      ),
      findsWidgets,
    );
  });
}
