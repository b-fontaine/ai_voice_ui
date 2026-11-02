import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';
import 'package:testing_real_fonts/testing_real_fonts.dart';

/// Mesure de l'ENCRE réelle (somme de la couverture des pixels, texte blanc
/// sur fond noir) : une police à chasse fixe ne change pas de largeur avec la
/// graisse, et le moteur de test ne dit pas si l'axe `wght` est appliqué.
///
/// Les polices sont chargées par `loadRealFonts` (testing_real_fonts), qui
/// lit les fichiers du paquet par `package_config.json` et les enregistre
/// sous les noms préfixés par `FontLoader`, comme le fait le moteur de l'app.
const String _sample = 'HEMNW 0123456789 99,43 % NO-GO ANDROID';

Future<double> _ink(
  WidgetTester tester,
  String family,
  FontWeight? weight,
  List<FontVariation>? variations,
) async {
  final GlobalKey key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: key,
          child: ColoredBox(
            color: const Color(0xFF000000),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                _sample,
                style: TextStyle(
                  color: const Color(0xFFFFFFFF),
                  fontFamily: family,
                  fontSize: 40,
                  fontWeight: weight,
                  fontVariations: variations,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  final RenderRepaintBoundary boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final double? ink = await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage();
    final ByteData data = (await image.toByteData())!;
    double sum = 0;
    for (int i = 0; i < data.lengthInBytes; i += 4) {
      sum += data.getUint8(i) / 255;
    }
    image.dispose();
    return sum;
  });
  return ink!;
}

void main() {
  setUpAll(() async {
    await loadRealFonts();
  });

  for (final String family in <String>[SceneFonts.sans, SceneFonts.mono]) {
    testWidgets('$family : l\'encre croît de wght 400 à 700', (
      WidgetTester tester,
    ) async {
      final double w400 = await _ink(
        tester,
        family,
        FontWeight.w400,
        const <FontVariation>[FontVariation('wght', 400)],
      );
      final double varOnly700 = await _ink(
        tester,
        family,
        null,
        const <FontVariation>[FontVariation('wght', 700)],
      );
      final double both700 = await _ink(
        tester,
        family,
        FontWeight.w700,
        const <FontVariation>[FontVariation('wght', 700)],
      );
      final double weightOnly700 = await _ink(
        tester,
        family,
        FontWeight.w700,
        null,
      );
      final double weightOnly400 = await _ink(
        tester,
        family,
        FontWeight.w400,
        null,
      );
      // ignore: avoid_print
      print(
        '$family encre : w400+var=$w400 | var700 seule=$varOnly700 | '
        'var700+w700=$both700 | w700 seul=$weightOnly700 | w400 seul=$weightOnly400',
      );
      expect(varOnly700, greaterThan(w400 * 1.10), reason: 'wght 700 seul');
      expect(both700, greaterThan(w400 * 1.10), reason: 'wght 700 + w700');
      expect(both700, closeTo(varOnly700, varOnly700 * 0.01));
      // Mesuré sous flutter_tester (Skia, Linux) : `fontWeight` seul règle
      // aussi l'axe `wght` d'un fichier variable, avec la même encre que
      // `FontVariation`. Le moteur de l'app (Impeller/Skia, autres
      // plateformes) peut différer : `sceneWeight` pose donc toujours les deux,
      // et la capture réelle (spikes/ds-fonts-weight) le revérifie.
      expect(weightOnly700, closeTo(varOnly700, varOnly700 * 0.01));
      expect(weightOnly400, closeTo(w400, w400 * 0.01));
    });
  }

  testWidgets('sceneWeight rend les quatre graisses dans l\'ordre croissant', (
    WidgetTester tester,
  ) async {
    for (final String family in <String>[SceneFonts.sans, SceneFonts.mono]) {
      final List<double> inks = <double>[];
      for (final int wght in <int>[400, 500, 600, 700]) {
        final SceneWeight w = sceneWeight(wght);
        inks.add(await _ink(tester, family, w.fontWeight, w.variations));
      }
      // ignore: avoid_print
      print('$family sceneWeight 400/500/600/700 : $inks');
      for (int i = 1; i < inks.length; i++) {
        expect(inks[i], greaterThan(inks[i - 1]), reason: '$family $inks');
      }
    }
  });
}
