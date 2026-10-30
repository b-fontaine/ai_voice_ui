import 'package:entity_catalog/entity_catalog.dart' show GenesisContract;
import 'package:flutter/widgets.dart' show Key, State;
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart' show Surface;

import '../support/catalog_harness.dart';

/// Sonde de propagation (009 T05) : un `updateDataModel` limité au
/// sous-chemin `/checklist/decisionStatus` doit reconstruire le composant lié
/// à `/checklist`, sans recréer la surface ni son `State`.
void main() {
  testWidgets('mise à jour du sous-chemin decisionStatus : Bloquée puis '
      'Validée, surface conservée', (tester) async {
    final h = CatalogHarness('checklist', 'checklist');
    await h.pump(tester);
    await h.sendFixtureTo(tester, 3);

    expect(h.inCell(find.text('En attente de décision')), findsOneWidget);
    final State<Surface> surfaceState = tester.state<State<Surface>>(
      find.descendant(
        of: find.byKey(const Key('surface-checklist')),
        matching: find.byType(Surface),
      ),
    );

    await h.send(
      tester,
      contractFixture(
        'block',
        GenesisContract.defaultCatalogId,
        variant: 'act3',
      ).single,
    );

    // L'ancien statut quitte la pastille à la fin de la transition.
    await tester.pump(const Duration(seconds: 1));

    expect(h.inCell(find.text('Bloquée')), findsOneWidget);
    expect(h.inCell(find.text('En attente de décision')), findsNothing);
    expect(h.inCell(find.text('Checklist go/no-go')), findsOneWidget);
    expect(h.inCell(find.text('À RISQUE')), findsOneWidget);
    expect(h.inCell(find.text('37 PR')), findsOneWidget);
    expect(
      identical(
        tester.state<State<Surface>>(find.byType(Surface)),
        surfaceState,
      ),
      isTrue,
      reason: 'la surface ne doit pas être recréée',
    );

    await h.send(
      tester,
      contractFixture(
        'validate',
        GenesisContract.defaultCatalogId,
        variant: 'act3',
      ).single,
    );

    await tester.pump(const Duration(seconds: 1));

    expect(h.inCell(find.text('Validée')), findsOneWidget);
    expect(h.inCell(find.text('Bloquée')), findsNothing);
    expect(h.inCell(find.text('Checklist go/no-go')), findsOneWidget);
    expect(h.inCell(find.text('À RISQUE')), findsOneWidget);
    expect(
      identical(
        tester.state<State<Surface>>(find.byType(Surface)),
        surfaceState,
      ),
      isTrue,
    );
    expect(h.engineErrors, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
