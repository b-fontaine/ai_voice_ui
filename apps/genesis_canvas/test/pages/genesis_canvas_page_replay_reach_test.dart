import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/page_rig.dart';

/// Atteignabilité du bouton Lecture avec le panneau du protocole déplié
/// (régression de T12b : l'étiquette « REJEU » en mono 24 px interlettré
/// poussait le bouton sous le panneau, qui recouvre la moitié droite de la
/// zone Rejeu). Le banc rend en Ahem (carré de 24 px par glyphe) : cas le plus
/// large, donc le plus sévère.
void main() {
  testWidgets('panneau déplié, le bouton Lecture reste atteignable', (
    tester,
  ) async {
    final rig = PageRig(tester);
    await rig.mount(tester, themed: true);
    await tester.tap(find.byKey(const Key('protocol-toggle')));
    await tester.pump();
    await tester.pump();

    final Rect panel = tester.getRect(find.byKey(const Key('protocol-panel')));
    final Rect bar = tester.getRect(find.byKey(const Key('replay-bar')));
    final Rect play = tester.getRect(find.byKey(const Key('replay-play')));
    expect(bar.width, 480);
    expect(
      bar.left,
      lessThan(panel.left),
      reason: 'le panneau recouvre la droite',
    );
    // Le centre, et 4 px de part et d'autre, tombent sur le bouton.
    for (final double dx in <double>[-4, 0, 4]) {
      final Offset point = play.center + Offset(dx, 0);
      expect(
        point.dx,
        lessThan(panel.left),
        reason: 'le point $point est sous le panneau (gauche ${panel.left})',
      );
    }
    await tester.tap(find.byKey(const Key('replay-play')));
    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const Key('replay-play')).hitTestable(),
      findsOneWidget,
      reason: 'le bouton Lecture doit recevoir le clic en son centre',
    );
  });
}
