import 'dart:ui' show Size, ViewConstraints;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:entity_catalog/entity_catalog.dart' show GenesisContract;
import 'package:genesis_widgetbook/widgetbook.config.dart';
import 'package:shared_design_system/shared_design_system.dart'
    show ScenePanelDecoration, SceneBackdrop;

/// Composants dont les stories doivent être habillées comme dans l'app : les
/// six composants genesis et les briques sans fond propre (T16/T18).
final _framed = <String>{
  ...GenesisContract.components,
  'DsStatusChip',
  'DsSkeleton',
  'DsNeutralState',
};

void main() {
  testWidgets('chaque story de composant a le panneau sur le fond à points', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    tester.view.physicalConstraints = ViewConstraints.tight(
      const Size(952, 318),
    );
    tester.view.devicePixelRatio = 1;

    for (final component in config.components) {
      for (final story in component.stories) {
        final scenario = story.allScenarios(config).first;
        final label = '${component.name}/${story.name}';
        await tester.pumpWidget(
          Builder(
            builder: (context) => scenario.buildWithConfig(context, config),
          ),
        );
        expect(find.byType(SceneBackdrop), findsWidgets, reason: label);
        if (!_framed.contains(component.name)) continue;
        final decoration = find.byType(ScenePanelDecoration);
        expect(decoration, findsOneWidget, reason: label);
        expect(
          find.ancestor(of: decoration, matching: find.byType(SceneBackdrop)),
          findsWidgets,
          reason: '$label : le panneau est posé au-dessus du fond',
        );
      }
    }
  });
}
