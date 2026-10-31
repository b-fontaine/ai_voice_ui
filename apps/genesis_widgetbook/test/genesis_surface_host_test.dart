import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_widgetbook/genesis/genesis_surface_host.dart';
import 'package:genesis_widgetbook/scene_app_builder.dart';
import 'package:shared_design_system/shared_design_system.dart'
    show SceneMotionScope;

/// Plafond d'attente d'un contenu (tours de 20 ms réelles + 50 ms simulées).
const _maxRounds = 100;

/// Monte (ou remonte, en conservant l'état de l'hôte) l'hôte comme le fait une
/// story : thème de scène, sans animation, dans une cellule de 624×302.
Future<void> _mount(
  WidgetTester tester,
  String example,
  GenesisSurfaceState state,
) => tester.pumpWidget(
  SceneMotionScope(
    disabled: true,
    child: Builder(
      builder: (context) => sceneAppBuilder(
        context,
        SizedBox(
          width: 624,
          height: 302,
          child: GenesisSurfaceHost(example: example, state: state),
        ),
      ),
    ),
  ),
);

/// Avance par petits tours jusqu'à ce que [expected] apparaisse. Les assets se
/// lisent en E/S réelles (`runAsync`), hors de l'horloge simulée. Échec
/// explicite si le plafond est atteint.
Future<void> _settle(WidgetTester tester, Finder expected) async {
  for (var i = 0; i < _maxRounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    if (expected.evaluate().isNotEmpty) return;
  }
  fail('contenu attendu absent après $_maxRounds tours : $expected');
}

Future<void> _pump(
  WidgetTester tester,
  String example,
  GenesisSurfaceState state,
  Finder expected,
) async {
  await _mount(tester, example, state);
  await _settle(tester, expected);
}

void main() {
  testWidgets('données : le texte du contrat apparaît (SurfaceController)', (
    tester,
  ) async {
    await _pump(
      tester,
      'act1-kpi',
      GenesisSurfaceState.data,
      find.text('99,57 %'),
    );
    expect(find.text('Sessions sans crash'), findsOneWidget);
    expect(find.text('99,57 %'), findsOneWidget);
    expect(find.byKey(const Key('nodata-kpi')), findsNothing);
    expect(find.byKey(const Key('neutral-kpi')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sans données : la cellule reconnaissable, sans texte', (
    tester,
  ) async {
    await _pump(
      tester,
      'act1-kpi',
      GenesisSurfaceState.noData,
      find.byKey(const Key('nodata-kpi')),
    );
    expect(find.byKey(const Key('nodata-kpi')), findsOneWidget);
    expect(find.text('99,57 %'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('neutre : données invalides, état neutre sans exception', (
    tester,
  ) async {
    await _pump(
      tester,
      'act1-kpi',
      GenesisSurfaceState.neutral,
      find.byKey(const Key('neutral-kpi')),
    );
    expect(find.byKey(const Key('neutral-kpi')), findsOneWidget);
    expect(find.text('Données indisponibles'), findsOneWidget);
    expect(find.text('99,57 %'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('changer d\'état recharge la surface : data puis noData', (
    tester,
  ) async {
    await _pump(
      tester,
      'act1-kpi',
      GenesisSurfaceState.data,
      find.text('99,57 %'),
    );
    await _mount(tester, 'act1-kpi', GenesisSurfaceState.noData);
    await _settle(tester, find.byKey(const Key('nodata-kpi')));
    expect(find.text('99,57 %'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('une erreur de lecture d\'asset est rendue visible', (
    tester,
  ) async {
    await _pump(
      tester,
      'inexistant',
      GenesisSurfaceState.data,
      find.byKey(const Key('host-error')),
    );
    expect(find.textContaining('inexistant'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
