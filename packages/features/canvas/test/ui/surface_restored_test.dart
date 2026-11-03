import 'package:feature_canvas/src/ui/surface_restored.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// `SurfaceRestored` : la surface était-elle déjà en place au montage
/// (restauration) ? Lue sans abonnement par les composants du catalogue pour
/// ne pas rejouer leurs animations ponctuelles (pdr-0088 F13).
void main() {
  testWidgets('of : vrai pour une surface restaurée seulement', (tester) async {
    bool? seen;
    Widget probe() => Builder(
      builder: (BuildContext context) {
        seen = SurfaceRestored.of(context);
        return const SizedBox.shrink();
      },
    );
    Widget host(Widget child) =>
        Directionality(textDirection: TextDirection.ltr, child: child);

    await tester.pumpWidget(
      host(SurfaceRestored(restored: true, child: probe())),
    );
    expect(seen, isTrue);
    await tester.pumpWidget(
      host(SurfaceRestored(restored: false, child: probe())),
    );
    expect(seen, isFalse);
    await tester.pumpWidget(host(probe()));
    expect(seen, isFalse, reason: "sans canevas : rien n'est restauré");
  });
}
