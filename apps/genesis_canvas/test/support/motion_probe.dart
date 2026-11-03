import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart' show DsBlink;

/// Outils de mesure du mouvement de niveau B (019 T34, pdr-0088 F9) : ils
/// lisent l'état réel des widgets du design system (période, contrôleur,
/// opacité courante, peintures du `RepaintBoundary`), sans rien doubler.

/// Le [DsBlink] qui enveloppe l'élément de clé [key].
Finder blinkOf(Key key) =>
    find.ancestor(of: find.byKey(key), matching: find.byType(DsBlink));

/// Opacité courante du clignotement qui enveloppe l'élément de clé [key].
double blinkOpacity(WidgetTester tester, Key key) => tester
    .widget<FadeTransition>(
      find
          .descendant(of: blinkOf(key), matching: find.byType(FadeTransition))
          .first,
    )
    .opacity
    .value;

/// Nombre de peintures du `RepaintBoundary` le plus proche au-dessus (ou égal
/// à) [finder].
int boundaryPaints(WidgetTester tester, Finder finder) {
  final Finder boundary = find
      .ancestor(of: finder, matching: find.byType(RepaintBoundary))
      .first;
  final RenderRepaintBoundary render = tester.renderObject(boundary);
  return render.debugSymmetricPaintCount + render.debugAsymmetricPaintCount;
}

/// Nombre de peintures du `RepaintBoundary` [boundary] lui-même.
int paintsOf(WidgetTester tester, Finder boundary) {
  final RenderRepaintBoundary render = tester.renderObject(boundary);
  return render.debugSymmetricPaintCount + render.debugAsymmetricPaintCount;
}

/// Contrat commun d'un clignotement `gc-blink` (`DsBlink`) autour de l'élément
/// de clé [key] de période [period] :
/// - période lue sur le widget ;
/// - plein pendant la première moitié, à 0,2 pendant la seconde ;
/// - un `RepaintBoundary` propre : le parent [outer] n'est pas repeint ;
/// - une reconstruction ne relance pas la boucle ([rebuild]) ;
/// - animations coupées (`mountDisabled`, si fourni) : plein, aucun `Ticker`.
Future<void> expectBlinkContract(
  WidgetTester tester, {
  required Key key,
  required Duration period,
  required Future<void> Function() mount,
  required Future<void> Function() rebuild,
  Future<void> Function()? mountDisabled,
  required Finder outer,
}) async {
  await mount();
  expect(blinkOf(key), findsOneWidget, reason: 'le clignotement existe');
  expect(tester.widget<DsBlink>(blinkOf(key)).period, period);
  expect(blinkOpacity(tester, key), 1, reason: 'plein au début de la période');

  final int outerBefore = paintsOf(tester, outer);
  final int half = period.inMilliseconds ~/ 2;
  await tester.pump(Duration(milliseconds: half + 100));
  expect(
    blinkOpacity(tester, key),
    DsBlink.dimmedOpacity,
    reason: 'seconde moitié de la période : 0,2',
  );
  expect(
    paintsOf(tester, outer),
    outerBefore,
    reason:
        'le clignotement a son RepaintBoundary : le parent ne se repeint pas',
  );

  // Une reconstruction ne redémarre pas la boucle : la phase continue.
  await rebuild();
  await tester.pump(Duration(milliseconds: period.inMilliseconds - half - 50));
  expect(
    blinkOpacity(tester, key),
    1,
    reason: 'phase continue (retour à plein à la période), sans redémarrage',
  );
  await tester.pump(Duration(milliseconds: half + 100));
  expect(blinkOpacity(tester, key), DsBlink.dimmedOpacity);

  if (mountDisabled != null) {
    await mountDisabled();
    expect(blinkOpacity(tester, key), 1, reason: 'phase de repos : plein');
    await tester.pump(Duration(milliseconds: period.inMilliseconds));
    expect(blinkOpacity(tester, key), 1, reason: 'jamais figé à demi-teinte');
    expect(tester.binding.transientCallbackCount, 0);
  }
}
