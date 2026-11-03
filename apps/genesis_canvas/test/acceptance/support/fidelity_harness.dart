import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'design_harness.dart';
import 'scene_palette.dart';
import 'scene_style_harness.dart';

/// Un morceau de texte d'un paragraphe, avec le style qui lui est appliqué
/// (celui de son `TextSpan` fusionné avec ceux de ses parents).
class SpanLeaf {
  const SpanLeaf(this.text, this.style);

  final String text;
  final TextStyle style;

  @override
  String toString() => '« $text » : ${style.fontSize} px';
}

/// Aides des scénarios de la spec 019 (V-01 à V-11, A-01 à A-07).
///
/// Elles observent l'écran rendu par **clés de widgets** (`<surface>-<partie>`,
/// voir `keys.dart`) : une clé absente est la raison d'échec d'un scénario
/// tant que la structure du design système n'est pas rendue. Aucune constante
/// ni aucun type de production n'est importé en dehors du thème de la scène.
abstract final class Fidelity {
  // --- Recherche ------------------------------------------------------------

  static Finder key(String name) => find.byKey(Key(name));

  /// Le seul widget de clé [name] ; échec explicite s'il manque ou s'il est en
  /// double.
  static Finder one(String name) {
    final Finder finder = key(name);
    expect(
      finder,
      findsOneWidget,
      reason:
          "l'élément « $name » est introuvable (ou en double) : la structure "
          'du design système (spec 019) ne le rend pas',
    );
    return finder;
  }

  static bool present(String name) => key(name).evaluate().isNotEmpty;

  // --- Texte ----------------------------------------------------------------

  static String _normalize(String text) =>
      text.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();

  /// Texte affiché par l'élément : tous ses `Text` (sinon ses `RichText`),
  /// séparés par une espace.
  static String textOf(Finder finder) {
    final List<String> texts = <String>[
      for (final Element e
          in find
              .descendant(
                of: finder,
                matching: find.byType(Text),
                matchRoot: true,
              )
              .evaluate())
        (e.widget as Text).data ??
            (e.widget as Text).textSpan?.toPlainText() ??
            '',
    ];
    if (texts.isNotEmpty) return texts.join(' ');
    return <String>[
      for (final Element e
          in find
              .descendant(
                of: finder,
                matching: find.byType(RichText),
                matchRoot: true,
              )
              .evaluate())
        (e.widget as RichText).text.toPlainText(),
    ].join(' ');
  }

  static String textOfKey(String name) => textOf(one(name));

  static bool sameText(String actual, String expected) =>
      _normalize(actual) == _normalize(expected);

  static bool containsText(String actual, String expected) =>
      _normalize(actual).contains(_normalize(expected));

  /// Les morceaux de texte de [span], avec leur style effectif.
  static List<SpanLeaf> leaves(InlineSpan span, [TextStyle? inherited]) {
    final TextStyle? style = inherited == null
        ? span.style
        : inherited.merge(span.style);
    final List<SpanLeaf> found = <SpanLeaf>[];
    if (span is TextSpan) {
      final String? text = span.text;
      if (text != null && text.trim().isNotEmpty) {
        found.add(SpanLeaf(text, style ?? const TextStyle()));
      }
      for (final InlineSpan child in span.children ?? const <InlineSpan>[]) {
        found.addAll(leaves(child, style));
      }
    }
    return found;
  }

  /// Le premier paragraphe de l'élément [name].
  static RenderParagraph paragraphOf(WidgetTester tester, String name) {
    final Finder paragraphs = find.descendant(
      of: one(name),
      matching: find.byType(RichText),
      matchRoot: true,
    );
    expect(
      paragraphs,
      findsWidgets,
      reason: "l'élément « $name » n'affiche aucun texte",
    );
    return tester.renderObject<RenderParagraph>(paragraphs.first);
  }

  /// Le style du premier morceau de texte de l'élément [name].
  static TextStyle styleOf(WidgetTester tester, String name) {
    final List<SpanLeaf> all = leaves(paragraphOf(tester, name).text);
    expect(
      all,
      isNotEmpty,
      reason: "l'élément « $name » n'affiche aucun texte",
    );
    return all.first.style;
  }

  /// Le premier nombre du texte de [name] (« 99,57 % » vaut 99.57).
  static double numberOf(String name) {
    final String text = textOfKey(name);
    final RegExpMatch? match = RegExp(r'\d+(?:[.,]\d+)?').firstMatch(text);
    expect(
      match,
      isNotNull,
      reason: "l'élément « $name » n'affiche aucun nombre (« $text »)",
    );
    return double.parse(match!.group(0)!.replaceAll(',', '.'));
  }

  // --- Échelle de texte (V-01) et contraste (V-11) -----------------------------

  /// Tailles de l'échelle de texte du design système (`tokens.json` et
  /// micro-styles de `bundle.css`, pdr-0088 F1), écrites en dur.
  static final Set<double> scaleSizes = <double>{
    76, 36, 28, 20, 18, 15, 14, 13, 12, 11, //
  };

  /// Rôles de `SceneTheme` par nom du design système.
  static const Map<String, String> roleOfStyle = <String, String>{
    'kpi-xl': 'value',
    'verdict': 'verdict',
    'data': 'data',
    'label': 'label',
    'title': 'title',
    'transcript': 'transcript',
    'body': 'body',
    'button': 'button',
  };

  static TextStyle sceneStyle(WidgetTester tester, String styleName) {
    final String? role = roleOfStyle[styleName];
    if (role == null) throw ArgumentError('style inconnu « $styleName »');
    final TextStyle? style = SceneStyleHarness.roleStyle(
      SceneStyleHarness.theme(tester),
      role,
    );
    expect(style, isNotNull, reason: 'SceneTheme sans style « $role »');
    return style!;
  }

  /// Les paragraphes visibles avec leurs morceaux de texte.
  static List<(Element, SpanLeaf)> visibleLeaves(WidgetTester tester) {
    final List<(Element, SpanLeaf)> all = <(Element, SpanLeaf)>[];
    for (final Element element in find.byType(RichText).evaluate()) {
      final RenderObject? render = element.renderObject;
      if (render is! RenderParagraph) continue;
      if (render.text.style?.fontFamily == 'MaterialIcons') continue;
      for (final SpanLeaf leaf in leaves(render.text)) {
        if (leaf.style.fontFamily == 'MaterialIcons') continue;
        all.add((element, leaf));
      }
    }
    return all;
  }

  static Color over(Color top, Color bottom) {
    final double a = top.a;
    return Color.from(
      alpha: 1,
      red: top.r * a + bottom.r * (1 - a),
      green: top.g * a + bottom.g * (1 - a),
      blue: top.b * a + bottom.b * (1 - a),
    );
  }

  /// Les fonds possibles sous le texte de [element] : les couches de couleur
  /// de ses ancêtres, composées sur le fond `void` de l'écran (un dégradé
  /// compte pour chacune de ses couleurs).
  static List<Color> backgroundsOf(Element element) {
    final List<List<Color>> layers = <List<Color>>[];
    element.visitAncestorElements((Element ancestor) {
      final Widget w = ancestor.widget;
      List<Color>? colors;
      if (w is ColoredBox) {
        colors = <Color>[w.color];
      } else if (w is DecoratedBox) {
        final Decoration d = w.decoration;
        if (d is BoxDecoration && w.position == DecorationPosition.background) {
          colors = d.gradient != null
              ? List<Color>.of(d.gradient!.colors)
              : (d.color != null ? <Color>[d.color!] : null);
        }
      } else if (w is Material &&
          w.type != MaterialType.transparency &&
          w.color != null) {
        colors = <Color>[w.color!];
      }
      if (colors != null) layers.add(colors);
      return true;
    });
    var candidates = <Color>[ScenePalette.voidColor];
    for (final List<Color> layer in layers.reversed) {
      candidates = <Color>[
        for (final Color base in candidates)
          for (final Color top in layer) over(top, base),
      ];
    }
    return candidates;
  }

  // --- Géométrie ------------------------------------------------------------

  static Rect rect(WidgetTester tester, String name) =>
      tester.getRect(one(name));

  static void expectNear(
    num actual,
    num expected,
    num tolerance, {
    required String what,
  }) {
    expect(
      (actual - expected).abs(),
      lessThanOrEqualTo(tolerance),
      reason: '$what : $actual, attendu $expected à $tolerance près',
    );
  }

  // --- Couleurs, formes, ombres --------------------------------------------------

  /// Les décorations de boîte (`DecoratedBox`) de l'élément, de l'extérieur
  /// vers l'intérieur.
  static List<Decoration> decorationsOf(Finder finder) => <Decoration>[
    for (final Element e
        in find
            .descendant(
              of: finder,
              matching: find.byWidgetPredicate((Widget w) => w is DecoratedBox),
              matchRoot: true,
            )
            .evaluate())
      (e.widget as DecoratedBox).decoration,
  ];

  /// Couleur de remplissage de l'élément : la première couleur de fond
  /// (`ColoredBox`, `DecoratedBox`) trouvée à l'intérieur.
  static Color? fillOf(Finder finder) {
    for (final Element e
        in find
            .descendant(
              of: finder,
              matching: find.byWidgetPredicate(
                (Widget w) => w is DecoratedBox || w is ColoredBox,
              ),
              matchRoot: true,
            )
            .evaluate()) {
      final Widget w = e.widget;
      if (w is ColoredBox) return w.color;
      final Decoration d = (w as DecoratedBox).decoration;
      if (d is BoxDecoration && d.color != null) return d.color;
    }
    return null;
  }

  /// Plus grand rayon de coin du premier arrondi trouvé dans l'élément.
  static double cornerRadiusOf(Finder finder) {
    for (final Element e
        in find
            .descendant(
              of: finder,
              matching: find.byWidgetPredicate(
                (Widget w) =>
                    w is DecoratedBox || w is ClipRRect || w is Material,
              ),
              matchRoot: true,
            )
            .evaluate()) {
      final Widget w = e.widget;
      BorderRadiusGeometry? radius;
      if (w is DecoratedBox) {
        final Decoration d = w.decoration;
        if (d is BoxDecoration) radius = d.borderRadius;
        if (d is ShapeDecoration && d.shape is RoundedRectangleBorder) {
          radius = (d.shape as RoundedRectangleBorder).borderRadius;
        }
        if (d is ShapeDecoration && d.shape is StadiumBorder) return 999;
      } else if (w is ClipRRect) {
        radius = w.borderRadius;
      } else if (w is Material) {
        final ShapeBorder? shape = w.shape;
        if (shape is RoundedRectangleBorder) radius = shape.borderRadius;
        if (shape is StadiumBorder) return 999;
        radius ??= w.borderRadius;
      }
      if (radius != null) {
        final BorderRadius resolved = radius.resolve(TextDirection.ltr);
        final double r = <double>[
          resolved.topLeft.x,
          resolved.topRight.x,
          resolved.bottomLeft.x,
          resolved.bottomRight.x,
        ].reduce(math.max);
        if (r > 0) return r;
      }
    }
    return 0;
  }

  /// Couleur de la première bordure trouvée dans l'élément.
  static Color? borderColorOf(Finder finder) {
    for (final Decoration d in decorationsOf(finder)) {
      if (d is BoxDecoration && d.border is Border) {
        final Border border = d.border! as Border;
        if (border.top.style != BorderStyle.none) return border.top.color;
      }
      if (d is ShapeDecoration && d.shape.dimensions != EdgeInsets.zero) {
        final ShapeBorder shape = d.shape;
        if (shape is RoundedRectangleBorder) return shape.side.color;
      }
    }
    return null;
  }

  /// Les ombres (`BoxShadow`) posées par les décorations de l'élément.
  static List<BoxShadow> shadowsOf(Finder finder) => <BoxShadow>[
    for (final Decoration d in decorationsOf(finder))
      if (d is BoxDecoration) ...?d.boxShadow,
  ];

  /// Égalité des canaux de couleur (l'alpha est ignoré : teinte).
  static bool sameTint(Color a, Color b) {
    int byte(double v) => (v * 255).round();
    return (byte(a.r) - byte(b.r)).abs() <= 2 &&
        (byte(a.g) - byte(b.g)).abs() <= 2 &&
        (byte(a.b) - byte(b.b)).abs() <= 2;
  }

  // --- Mouvement ---------------------------------------------------------------

  /// Le `RepaintBoundary` de l'élément (lui-même ou le premier dedans).
  static RenderRepaintBoundary? boundaryOf(Finder finder) {
    for (final Element e
        in find
            .descendant(
              of: finder,
              matching: find.byType(RepaintBoundary),
              matchRoot: true,
            )
            .evaluate()) {
      final RenderObject? render = e.renderObject;
      if (render is RenderRepaintBoundary) return render;
    }
    return null;
  }

  static int _paints(RenderRepaintBoundary boundary) =>
      boundary.debugSymmetricPaintCount + boundary.debugAsymmetricPaintCount;

  /// L'élément se repeint-il pendant les prochaines images ? Il faut qu'il
  /// porte (ou contienne) son propre `RepaintBoundary` : toute boucle a le
  /// sien (plan 019, P2).
  static Future<bool> repaints(WidgetTester tester, String name) async {
    final Finder finder = one(name);
    final RenderRepaintBoundary? boundary = boundaryOf(finder);
    expect(
      boundary,
      isNotNull,
      reason:
          "l'élément « $name » n'a pas de RepaintBoundary local : une boucle "
          'doit être isolée (NFR-04)',
    );
    final int before = _paints(boundary!);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final RenderRepaintBoundary? after = boundaryOf(key(name));
    return after != null && _paints(after) > (after == boundary ? before : 0);
  }

  /// Opacité rendue de l'élément (produit des opacités de ses ancêtres).
  static double opacity(String name) =>
      DesignHarness.renderedOpacity(one(name), what: "l'élément « $name »");

  /// Flou (σ) appliqué au contenu par un `ImageFiltered` actif ; 0 sans flou.
  static double blurOf(Finder finder) {
    var sigma = 0.0;
    finder.evaluate().first.visitAncestorElements((Element ancestor) {
      final Widget w = ancestor.widget;
      if (w is ImageFiltered && w.enabled) {
        final RegExpMatch? match = RegExp(r'blur\(([\d.]+)')
            .firstMatch(w.imageFilter.toString());
        if (match != null) {
          sigma = math.max(sigma, double.parse(match.group(1)!));
        }
      }
      return true;
    });
    return sigma;
  }

  /// Échelle horizontale rendue du contenu (produit des transformations de
  /// ses ancêtres).
  static double scaleOf(Finder finder) {
    final RenderObject? render = finder.evaluate().first.renderObject;
    if (render is! RenderBox) return 1;
    return render.getTransformTo(null).storage[0];
  }

  /// Fraction (0 à 1) de la largeur de l'élément que son `ClipRect` laisse
  /// voir : le tracé du graphique se dévoile par un `ClipRect` à `clipper`.
  static double visibleFraction(String name) {
    final Finder finder = one(name);
    final List<Element> clips = find
        .descendant(
          of: finder,
          matching: find.byType(ClipRect),
          matchRoot: true,
        )
        .evaluate()
        .toList();
    expect(
      clips,
      isNotEmpty,
      reason:
          "l'élément « $name » ne contient aucun ClipRect : le tracé ne se "
          'dévoile pas de gauche à droite',
    );
    for (final Element e in clips) {
      final RenderObject? render = e.renderObject;
      if (render is RenderClipRect && render.clipper != null) {
        final Rect clip = render.clipper!.getClip(render.size);
        return (clip.width / render.size.width).clamp(0.0, 1.0);
      }
    }
    return 1;
  }
}
