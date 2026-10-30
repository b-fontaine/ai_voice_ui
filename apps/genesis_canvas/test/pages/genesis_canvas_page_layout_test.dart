import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_canvas/widgets/top_bar/top_bar.dart';
import 'package:shared_design_system/shared_design_system.dart';

import '../support/page_rig.dart';
import '../support/paragraphs.dart';

/// Test de page à 1920 × 1080, DPR 1 (A7d du plan 007) : les quatre fixtures du
/// contrat jouées par le faux canal, panneau replié puis déplié. Aucune erreur
/// de rendu (dont les débordements), tout texte de l'écran à 24 px au moins,
/// zones aux hauteurs du budget.
///
/// Les tests de widgets de `flutter_test` rendent le texte avec la police
/// Ahem (chaque glyphe fait un carré de la taille de la police) : c'est un
/// cas bien plus large que Roboto, donc un contrôle de débordement sévère.
void main() {
  Future<PageRig> playAct1(WidgetTester tester) async {
    final rig = PageRig(tester);
    await rig.mount(tester, themed: true);
    await rig.start(tester);
    for (final envelope in await act1Envelopes(tester)) {
      rig.receiveEnvelope(envelope);
      await tester.pump();
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 50));
    return rig;
  }

  Rect rectOf(WidgetTester tester, String key) =>
      tester.getRect(find.byKey(Key(key)));

  void expectCleanScreen(WidgetTester tester, PageRig rig) {
    expect(tester.takeException(), isNull);
    expect(rig.errors.toString(), isEmpty);
    expect(
      paragraphsBelowMinimum(tester),
      isEmpty,
      reason: 'tout texte de l\'écran doit faire au moins 24 px',
    );
  }

  testWidgets('acte 1 complet, panneau replié : zones au budget, aucun '
      'débordement, texte >= 24 px', (tester) async {
    final rig = await playAct1(tester);

    expectCleanScreen(tester, rig);
    // Les quatre surfaces de l'acte 1 sont rendues, aux emplacements
    // déterministes (2 × 2).
    final cells = [
      for (final id in const ['kpi', 'trend', 'reviews', 'checklist'])
        rectOf(tester, 'surface-$id'),
    ];
    expect(cells[1].left, greaterThan(cells[0].left));
    expect(cells[2].top, greaterThan(cells[0].top));
    expect(cells[3].topLeft, Offset(cells[1].left, cells[2].top));
    for (final cell in cells) {
      expect(cell.width, greaterThanOrEqualTo(900));
      expect(cell.height, greaterThanOrEqualTo(250));
    }
    // Budget des zones (A7b) : barre 160, rail 200, canevas 520, rangée 140.
    expect(tester.getSize(find.byType(TopBar)).height, 160);
    expect(rectOf(tester, 'agents-rail').height, lessThanOrEqualTo(200));
    expect(rectOf(tester, 'canvas-board').height, 520);
    expect(rectOf(tester, 'catalog-shelf').height, lessThanOrEqualTo(140));
    expect(rectOf(tester, 'protocol-panel').height, 140);
    expect(rectOf(tester, 'replay-bar').height, lessThanOrEqualTo(140));
    // Le tout tient dans l'écran.
    for (final key in const [
      'agents-rail',
      'canvas-board',
      'catalog-shelf',
      'protocol-panel',
      'replay-bar',
      'act-indicator',
      'reset-button',
    ]) {
      final r = rectOf(tester, key);
      expect(r.left, greaterThanOrEqualTo(0), reason: key);
      expect(r.top, greaterThanOrEqualTo(0), reason: key);
      expect(r.right, lessThanOrEqualTo(1920), reason: key);
      expect(r.bottom, lessThanOrEqualTo(1080), reason: key);
    }
    // Rail, étagère, indicateur d'acte et panneau sont tous présents.
    expect(find.byKey(const Key('agent-Qualité')), findsOneWidget);
    expect(find.text('4 / 6 utilisés'), findsOneWidget);
    expect(find.textContaining('Acte 1/3'), findsOneWidget);
    expect(find.byKey(const Key('protocol-entry-0')), findsNothing);
    // Le thème de scène est installé au niveau du ThemeData.
    expect(
      Theme.of(rig.context).extension<SceneTheme>(),
      const SceneTheme.dark(),
    );
  });

  testWidgets('panneau déplié : recouvre le canevas à droite sans le '
      'redimensionner, aucun débordement', (tester) async {
    final rig = await playAct1(tester);
    final board = rectOf(tester, 'canvas-board');
    final cells = {
      for (final id in const ['kpi', 'trend', 'reviews', 'checklist'])
        id: rectOf(tester, 'surface-$id'),
    };

    await tester.tap(find.byKey(const Key('protocol-toggle')));
    await tester.pump();
    await tester.pump();

    expectCleanScreen(tester, rig);
    expect(find.byKey(const Key('protocol-entry-11')), findsOneWidget);
    expect(find.byKey(const Key('protocol-current')), findsOneWidget);
    final panel = rectOf(tester, 'protocol-panel');
    expect(panel.height, greaterThan(140));
    expect(panel.overlaps(board), isTrue, reason: 'recouvre le canevas');
    expect(panel.right, lessThanOrEqualTo(1920));
    expect(panel.top, greaterThanOrEqualTo(0));
    // Le canevas et ses cellules n'ont pas bougé.
    expect(rectOf(tester, 'canvas-board'), board);
    for (final entry in cells.entries) {
      expect(rectOf(tester, 'surface-${entry.key}'), entry.value);
    }
    // La surface du message en cours est cerclée.
    expect(find.byKey(const Key('highlight-checklist')), findsOneWidget);

    // Replié de nouveau : le panneau reprend sa place de 140 px.
    await tester.tap(find.byKey(const Key('protocol-toggle')));
    await tester.pump();
    await tester.pump();
    expectCleanScreen(tester, rig);
    expect(rectOf(tester, 'protocol-panel').height, 140);
  });

  testWidgets('écran vide au départ : zones présentes, aucun débordement', (
    tester,
  ) async {
    final rig = PageRig(tester);
    await rig.mount(tester, themed: true);
    await rig.start(tester);

    expectCleanScreen(tester, rig);
    expect(find.text('0 / 6 utilisés'), findsOneWidget);
    expect(find.text('REJEU'), findsOneWidget);
    expect(find.textContaining('Acte 1/3'), findsOneWidget);
  });

  testWidgets('après la remise à vide : écran initial, aucun débordement', (
    tester,
  ) async {
    final rig = await playAct1(tester);

    await tester.tap(find.byKey(const Key('reset-button')));
    await tester.pump();
    await tester.pump();

    expectCleanScreen(tester, rig);
    expect(find.byKey(const Key('surface-kpi')), findsNothing);
    expect(find.text('0 / 6 utilisés'), findsOneWidget);
    expect(find.byKey(const Key('agent-Qualité')), findsNothing);
    expect(rig.resetClient.calls, 1);
  });
}
