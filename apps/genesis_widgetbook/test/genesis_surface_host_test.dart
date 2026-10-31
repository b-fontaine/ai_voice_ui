import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_widgetbook/genesis/genesis_surface_host.dart';
import 'package:genesis_widgetbook/scene_app_builder.dart';
import 'package:shared_design_system/shared_design_system.dart'
    show SceneMotionScope;

/// Monte l'hôte comme le fait une story : thème de scène, sans animation.
Future<void> _pump(
  WidgetTester tester,
  String example,
  GenesisSurfaceState state,
) async {
  await tester.pumpWidget(
    SceneMotionScope(
      disabled: true,
      child: Builder(
        builder: (context) => sceneAppBuilder(
          context,
          SizedBox(
            width: 604,
            height: 286,
            child: GenesisSurfaceHost(example: example, state: state),
          ),
        ),
      ),
    ),
  );
  // Les assets se lisent en E/S réelles : hors de l'horloge simulée.
  await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('données : le texte du contrat apparaît (SurfaceController)', (
    tester,
  ) async {
    await _pump(tester, 'act1-kpi', GenesisSurfaceState.data);
    expect(find.text('Sessions sans crash'), findsOneWidget);
    expect(find.text('99,57 %'), findsOneWidget);
    expect(find.byKey(const Key('nodata-kpi')), findsNothing);
    expect(find.byKey(const Key('neutral-kpi')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sans données : la cellule reconnaissable, sans texte', (
    tester,
  ) async {
    await _pump(tester, 'act1-kpi', GenesisSurfaceState.noData);
    expect(find.byKey(const Key('nodata-kpi')), findsOneWidget);
    expect(find.text('99,57 %'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('neutre : données invalides, état neutre sans exception', (
    tester,
  ) async {
    await _pump(tester, 'act1-kpi', GenesisSurfaceState.neutral);
    expect(find.byKey(const Key('neutral-kpi')), findsOneWidget);
    expect(find.text('Données indisponibles'), findsOneWidget);
    expect(find.text('99,57 %'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
