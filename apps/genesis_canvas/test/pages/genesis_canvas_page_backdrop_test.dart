import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_canvas/widgets/replay_bar/replay_bar.dart';
import 'package:shared_design_system/shared_design_system.dart';

import '../support/page_rig.dart';

/// Fond de page (pdr-0084 U9) : la grille de points est dans la frontière de
/// capture, sous le contenu, et couvre tout l'écran.
void main() {
  testWidgets('le fond à points est sous le contenu, dans la frontière de '
      'capture, et couvre l\'écran', (tester) async {
    final rig = PageRig(tester);
    await rig.mount(tester, themed: true);

    final Finder backdrop = find.byType(SceneBackdrop);
    expect(backdrop, findsOneWidget);
    expect(tester.getRect(backdrop), const Rect.fromLTWH(0, 0, 1920, 1080));

    // Une frontière de capture contient à la fois le fond et le contenu.
    final bool shared = find
        .ancestor(of: backdrop, matching: find.byType(RepaintBoundary))
        .evaluate()
        .any(
          (Element boundary) => find
              .descendant(
                of: find.byWidget(boundary.widget),
                matching: find.byType(ReplayBar),
              )
              .evaluate()
              .isNotEmpty,
        );
    expect(shared, isTrue, reason: 'fond et contenu dans une même frontière');

    // Sous le contenu : le fond est peint avant la barre de rejeu.
    final List<Widget> order = tester.allWidgets.toList();
    expect(
      order.indexWhere((Widget w) => w is SceneBackdrop),
      lessThan(order.indexWhere((Widget w) => w is ReplayBar)),
    );
  });
}
