import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: la fenêtre de l'app fait {1366} sur {768} px
///
/// Redimensionne la fenêtre (pixel logique = pixel physique) : le statut de
/// décision doit rester lisible sur un écran de portable. Les autres surfaces
/// et l'étagère débordent déjà sous 1080p (hors périmètre de la spec 011) :
/// leurs débordements sont ignorés, ceux de la checklist restent signalés.
Future<void> laFenetreDeLappFaitSurPx(
  WidgetTester tester,
  num width,
  num height,
) async {
  final original = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    final text = details.toString();
    if (text.contains('RenderFlex overflowed') &&
        !text.contains('release_checklist.dart')) {
      return;
    }
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);
  tester.view.physicalSize = Size(width.toDouble(), height.toDouble());
  tester.view.devicePixelRatio = 1;
  await tester.pump();
}
