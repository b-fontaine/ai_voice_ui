import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_until.dart';
import 'keys.dart';

/// Aides des scénarios L-01 à L-04 (spec 015) : présence des liaisons du rail
/// par leur clé `delegation-link-<agent>`, et image de la zone d'une liaison
/// pour dire si ses pointillés défilent. Aucune constante de production n'est
/// importée : un scénario échoue parce que la liaison manque, jamais parce
/// qu'un symbole manque.
class DelegationLinkHarness {
  DelegationLinkHarness._();

  static final Map<String, Uint8List> noted = <String, Uint8List>{};

  static Finder link(String agent) =>
      find.byKey(AcceptanceKeys.delegationLink(agent));

  /// Toutes les liaisons actuellement montées.
  static Finder get anyLink => find.byWidgetPredicate(
    (widget) =>
        widget.key is ValueKey<String> &&
        (widget.key! as ValueKey<String>).value.startsWith(
          AcceptanceKeys.delegationLinkPrefix,
        ),
  );

  static Future<void> expectLinkAbsentSoon(WidgetTester tester, String agent) =>
      pumpUntil(
        tester,
        () => link(agent).evaluate().isEmpty,
        timeout: const Duration(seconds: 2),
        reason: "la liaison de l'agent $agent est restée affichée",
      );

  /// Pixels (RGBA) de la zone de la liaison de [agent], rendus tels quels.
  static Future<Uint8List> capture(WidgetTester tester, String agent) async {
    final finder = link(agent);
    if (finder.evaluate().isEmpty) {
      fail("la liaison de l'agent $agent n'est pas affichée : rien à capturer");
    }
    final RenderBox box = tester.renderObject<RenderBox>(finder.first);
    RenderObject? node = box;
    while (node != null && node is! RenderRepaintBoundary) {
      node = node.parent;
    }
    if (node == null) {
      fail('aucune frontière de repeinture au-dessus de la liaison');
    }
    final boundary = node as RenderRepaintBoundary;
    final Rect area =
        (box.localToGlobal(Offset.zero, ancestor: boundary) & box.size)
            .intersect(Offset.zero & boundary.size);
    final ui.Image image = (await tester.runAsync(
      () => boundary.toImage(pixelRatio: 1),
    ))!;
    final ByteData data = (await tester.runAsync(() async {
      final ByteData? raw = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      return raw!;
    }))!;
    final pixels = data.buffer.asUint8List();
    final int width = image.width;
    final int left = area.left.floor();
    final int right = area.right.ceil();
    final int top = area.top.floor();
    final int bottom = area.bottom.ceil();
    final out = BytesBuilder();
    for (var y = top; y < bottom; y++) {
      out.add(pixels.sublist((y * width + left) * 4, (y * width + right) * 4));
    }
    return out.takeBytes();
  }
}
