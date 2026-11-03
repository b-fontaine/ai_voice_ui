import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

import '../support/catalog_harness.dart';

/// Compteur du chiffre héros (`data-count`, pdr-0088 F3 et F13) : de 100 vers
/// la valeur en 1,4 s, texte final égal à la chaîne de données.
const ({bool disabled, double speed}) _live = (disabled: false, speed: 1);
const ({bool disabled, double speed}) _still = (disabled: true, speed: 1);

String _shown(WidgetTester tester) =>
    (tester.widget(find.byKey(const Key('kpi-value'))) as Text).textSpan!
        .toPlainText();

double _number(WidgetTester tester) => double.parse(
  RegExp(r'\d+,\d+').firstMatch(_shown(tester))!.group(0)!.replaceAll(',', '.'),
);

Future<CatalogHarness> _live1(WidgetTester tester) async {
  final h = CatalogHarness('kpi', 'kpi');
  await h.pump(tester, motion: _live);
  await h.sendFixtureTo(tester, 3);
  return h;
}

void main() {
  testWidgets('descend de 100 vers 99,57 en 1,4 s, texte final exact', (
    tester,
  ) async {
    await _live1(tester);
    expect(_shown(tester), '100,00 %');

    await tester.pump(const Duration(milliseconds: 100));
    final double early = _number(tester);
    expect(early, inExclusiveRange(99.57, 100));

    await tester.pump(const Duration(milliseconds: 600));
    final double mid = _number(tester);
    expect(mid, lessThan(early));
    expect(mid, greaterThan(99.57));
    expect(RegExp(r'^\d+,\d{2} %$').hasMatch(_shown(tester)), isTrue);

    await tester.pump(SceneMotion.count - const Duration(milliseconds: 700));
    expect(_shown(tester), '99,57 %');
    await tester.pump(const Duration(milliseconds: 20));
    expect(tester.binding.transientCallbackCount, 0);
    expect(find.text('99,57 %'), findsOneWidget);
  });

  testWidgets('animations coupées : la chaîne de données aussitôt', (
    tester,
  ) async {
    final h = CatalogHarness('kpi', 'kpi');
    await h.pump(tester, motion: _still);
    await h.sendFixtureTo(tester, 3);
    expect(_shown(tester), '99,57 %');
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('rejeu à 2 x : la moitié du temps', (tester) async {
    final h = CatalogHarness('kpi', 'kpi');
    await h.pump(tester, motion: (disabled: false, speed: 2));
    await h.sendFixtureTo(tester, 3);
    await tester.pump(SceneMotion.count ~/ 2);
    expect(_shown(tester), '99,57 %');
  });

  testWidgets('animations coupées en cours de route : état final aussitôt', (
    tester,
  ) async {
    final h = CatalogHarness('kpi', 'kpi');
    await h.pump(tester, motion: _live);
    await h.sendFixtureTo(tester, 3);
    await tester.pump(const Duration(milliseconds: 300));
    expect(_shown(tester), isNot('99,57 %'));
    await h.pump(tester, motion: _still);
    await tester.pump();
    expect(_shown(tester), '99,57 %');
  });

  testWidgets('la mutation de l\'acte 2 rejoue le compteur depuis 100', (
    tester,
  ) async {
    final h = await _live1(tester);
    await tester.pump(SceneMotion.count + const Duration(milliseconds: 50));
    expect(_shown(tester), '99,57 %');

    await h.sendVariant(tester, 'act2');
    await tester.pump(const Duration(milliseconds: 50));
    expect(_number(tester), greaterThan(99.57));
    await tester.pump(SceneMotion.count);
    expect(_shown(tester), '99,43 %');
  });

  testWidgets('une mise à jour sans changement de valeur ne rejoue rien', (
    tester,
  ) async {
    final h = await _live1(tester);
    await tester.pump(SceneMotion.count + const Duration(milliseconds: 50));
    await h.sendData(tester, cloneJson(h.data)..['trend'] = '−0,40 pt');
    expect(_shown(tester), '99,57 %');
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('valeur illisible : aucune animation, chaîne telle quelle', (
    tester,
  ) async {
    final h = CatalogHarness('kpi', 'kpi');
    await h.pump(tester, motion: _live);
    await h.sendFixtureTo(tester, 2);
    await h.sendData(tester, cloneJson(h.data)..['value'] = 'n/d');
    await tester.pump(SceneMotion.appear + const Duration(milliseconds: 50));
    expect(find.text('n/d'), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('valeur à une décimale : texte final exact, pas « 99,80 »', (
    tester,
  ) async {
    final h = CatalogHarness('kpi', 'kpi');
    await h.pump(tester, motion: _live);
    await h.sendFixtureTo(tester, 2);
    await h.sendData(tester, cloneJson(h.data)..['value'] = '99,8 %');
    await tester.pump(SceneMotion.count + const Duration(milliseconds: 50));
    expect(_shown(tester), '99,8 %');
  });
}
