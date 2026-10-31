import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart' show Surface;
import 'package:testing_real_fonts/testing_real_fonts.dart';

import 'keys.dart';

/// État et aides partagés par les scénarios de la spec 013 (D-01 à D-07).
///
/// Les mesures sont celles de l'écran rendu : rectangles des clés existantes
/// (`agents-rail`, `canvas-board`, `surface-<id>`…), paragraphes tronqués
/// (`RenderParagraph.didExceedMaxLines`, polices réelles) et opacité rendue
/// (produit des opacités des ancêtres). Aucune constante de production n'est
/// importée : un scénario échoue parce qu'un comportement manque, jamais parce
/// qu'un symbole manque.
class DesignHarness {
  DesignHarness._();

  /// Zones de l'écran dont la place ne doit jamais changer (hors rail vide,
  /// dont la hauteur est fixe).
  static const List<Key> zoneKeys = <Key>[
    AcceptanceKeys.agentsRail,
    AcceptanceKeys.canvasBoard,
    AcceptanceKeys.catalogShelf,
    AcceptanceKeys.protocolPanel,
  ];

  /// Surfaces que les scénarios savent reconnaître dans le canevas.
  static const List<String> knownSurfaces = <String>[
    ...AcceptanceKeys.act1Surfaces,
    'crashes',
    'actions',
  ];

  static final Map<Key, Rect> notedZones = <Key, Rect>{};
  static final Map<String, Rect> notedSurfaces = <String, Rect>{};
  static final Map<String, IconData> shelfIcons = <String, IconData>{};
  static bool fontsLoaded = false;

  static void reset() {
    notedZones.clear();
    notedSurfaces.clear();
    shelfIcons.clear();
  }

  /// Charge les polices réelles une fois par processus de test. `Roboto`, la
  /// famille par défaut du thème Material (Android comme Linux), reçoit la
  /// police du texte courant : l'app, qui ne fixe pas sa police, se rend ainsi
  /// avec des glyphes réels.
  static Future<void> ensureRealFonts() async {
    if (fontsLoaded) return;
    await loadRealFonts(alsoAs: const <String>['Roboto']);
    fontsLoaded = true;
  }

  static Finder surface(String id) => find.byKey(AcceptanceKeys.surface(id));

  static Rect rectOf(WidgetTester tester, Key key) {
    final finder = find.byKey(key);
    expect(finder, findsOneWidget, reason: 'widget $key introuvable');
    return tester.getRect(finder);
  }

  /// Rectangles des surfaces présentes dans le canevas.
  static Map<String, Rect> surfaceRects(WidgetTester tester) => <String, Rect>{
    for (final id in knownSurfaces)
      if (surface(id).evaluate().isNotEmpty) id: tester.getRect(surface(id)),
  };

  static void noteZones(WidgetTester tester) {
    notedZones
      ..clear()
      ..addAll(<Key, Rect>{
        for (final key in zoneKeys) key: rectOf(tester, key),
      });
  }

  static void noteSurfaces(WidgetTester tester) {
    notedSurfaces
      ..clear()
      ..addAll(surfaceRects(tester));
  }

  /// Compare [now] aux rectangles notés ; la description des écarts, ou `null`.
  static String? movedRects<K>(Map<K, Rect> noted, Map<K, Rect> now) {
    final moved = <String>[];
    for (final entry in noted.entries) {
      final current = now[entry.key];
      if (current != entry.value) {
        moved.add('${entry.key} : ${entry.value} -> $current');
      }
    }
    return moved.isEmpty ? null : moved.join('\n');
  }

  /// Fait avancer le temps simulé de [total] par images de 16 ms ; [onFrame]
  /// est appelé après chaque image.
  static Future<void> elapse(
    WidgetTester tester,
    Duration total, {
    void Function()? onFrame,
  }) async {
    const frame = Duration(milliseconds: 16);
    var done = Duration.zero;
    while (done < total) {
      final step = total - done < frame ? total - done : frame;
      await tester.pump(step);
      done += step;
      onFrame?.call();
    }
  }

  /// Opacité rendue de [finder] : produit des opacités de ses ancêtres
  /// (`Opacity`, `FadeTransition`, `AnimatedOpacity`).
  static double renderedOpacity(Finder finder, {required String what}) {
    final elements = finder.evaluate();
    expect(elements, isNotEmpty, reason: '$what est introuvable');
    var opacity = 1.0;
    RenderObject? render = elements.first.renderObject;
    while (render != null) {
      if (render is RenderOpacity) opacity *= render.opacity;
      if (render is RenderAnimatedOpacity) opacity *= render.opacity.value;
      render = render.parent;
    }
    return opacity;
  }

  /// Le moteur de rendu (`Surface`) de la surface [id] : son contenu, hors
  /// squelette.
  static Finder contentOf(String id) =>
      find.descendant(of: surface(id), matching: find.byType(Surface));

  /// Plus petite cible (largeur, hauteur) de la commande de clé [key] : le
  /// bouton Material qu'elle porte ou contient, sinon le widget lui-même.
  static Size targetSize(WidgetTester tester, Key key) {
    final keyed = find.byKey(key);
    expect(keyed, findsOneWidget, reason: 'widget $key introuvable');
    final buttons = find.descendant(
      of: keyed,
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      matchRoot: true,
    );
    return tester.getSize(
      buttons.evaluate().isNotEmpty ? buttons.first : keyed,
    );
  }
}
