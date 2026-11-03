import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';
import 'package:testing_real_fonts/testing_real_fonts.dart';

/// Aides des scénarios U-01 à U-06 (spec 017) : texte visible, polices par
/// rôle du thème de la scène, statuts, mouvement. Elles observent l'écran
/// rendu ; aucune constante de production n'est importée.
abstract final class SceneStyleHarness {
  static const String spaceGrotesk = 'Space Grotesk';
  static const String jetBrainsMono = 'JetBrains Mono';

  /// Préfixe de famille que Flutter pose sur les polices d'un paquet.
  static const String packagePrefix = 'packages/shared_design_system/';

  /// Les paragraphes visibles de l'écran (hors `Offstage`, hors glyphes
  /// d'icônes, hors texte vide), `Material` compris.
  static List<RenderParagraph> visibleParagraphs(WidgetTester tester) {
    return tester
        .renderObjectList<RenderParagraph>(find.byType(RichText))
        .where((RenderParagraph p) {
          if (p.text.toPlainText().trim().isEmpty) return false;
          return p.text.style?.fontFamily != 'MaterialIcons';
        })
        .toList();
  }

  /// Le nom de famille sans le préfixe de paquet.
  static String? bareFamily(String? family) =>
      family != null && family.startsWith(packagePrefix)
      ? family.substring(packagePrefix.length)
      : family;

  /// Le thème de la scène tel qu'il est posé sous la page.
  static SceneTheme theme(WidgetTester tester) {
    final Finder anyText = find.byType(RichText);
    expect(anyText, findsWidgets, reason: "l'écran n'affiche aucun texte");
    final SceneTheme? theme = Theme.of(tester.element(anyText.first))
        .extension<SceneTheme>();
    expect(theme, isNotNull, reason: 'SceneTheme absent du thème (RG-09)');
    return theme!;
  }

  /// Rôles de texte du `SceneTheme` qui portent des données (JetBrains Mono) :
  /// valeur, donnée, étiquette, verdict.
  static const List<String> dataRoles = <String>[
    'value',
    'data',
    'label',
    'verdict',
  ];

  /// Rôles de texte du `SceneTheme` qui portent des mots (Space Grotesk) :
  /// titre, texte courant, bouton, transcription.
  static const List<String> wordRoles = <String>[
    'title',
    'body',
    'button',
    'transcript',
  ];

  static final Map<String, TextStyle Function(dynamic)> _roleGetters =
      <String, TextStyle Function(dynamic)>{
        'value': (dynamic t) => t.value as TextStyle,
        'data': (dynamic t) => t.data as TextStyle,
        'label': (dynamic t) => t.label as TextStyle,
        'verdict': (dynamic t) => t.verdict as TextStyle,
        'title': (dynamic t) => t.title as TextStyle,
        'body': (dynamic t) => t.body as TextStyle,
        'button': (dynamic t) => t.button as TextStyle,
        'transcript': (dynamic t) => t.transcript as TextStyle,
      };

  /// Le style du rôle [role] dans [theme] ; `null` si le thème ne porte pas
  /// encore ce rôle (les rôles `data`, `verdict`, `button`, `transcript`
  /// arrivent avec 017).
  static TextStyle? roleStyle(SceneTheme theme, String role) {
    try {
      return _roleGetters[role]!(theme);
    } on NoSuchMethodError {
      return null;
    }
  }

  /// Un texte appartient à un rôle quand sa taille, sa graisse, son interligne
  /// et, quand le rôle en fixe un, son interlettrage sont ceux du style du rôle (la famille n'entre pas
  /// dans la comparaison : c'est ce que les scénarios vérifient).
  static bool matchesRole(TextStyle? style, TextStyle role) {
    if (style == null || style.fontSize == null) return false;
    bool near(double? a, double? b, double eps) =>
        ((a ?? 0) - (b ?? 0)).abs() <= eps;
    return near(style.fontSize, role.fontSize, 0.01) &&
        (style.fontWeight ?? FontWeight.w400) ==
            (role.fontWeight ?? FontWeight.w400) &&
        near(style.height, role.height, 0.001) &&
        // Le style ambiant de Material impose 0,25 px d'interlettrage aux
        // textes qui n'en fixent pas : on ne compare que s'il est fixé.
        (role.letterSpacing == null ||
            near(style.letterSpacing, role.letterSpacing, 0.01));
  }

  /// Paragraphes visibles dont le style correspond à un des [roles] et à
  /// aucun des [otherRoles] (un style commun aux deux familles de rôles ne
  /// prouve rien et n'est pas classé).
  static List<RenderParagraph> paragraphsOfRoles(
    WidgetTester tester, {
    required List<String> roles,
    required List<String> otherRoles,
  }) {
    final SceneTheme sceneTheme = theme(tester);
    List<TextStyle> styles(List<String> names) => <TextStyle>[
      for (final String name in names) ?roleStyle(sceneTheme, name),
    ];
    final List<TextStyle> mine = styles(roles);
    final List<TextStyle> others = styles(otherRoles);
    return visibleParagraphs(tester).where((RenderParagraph p) {
      final TextStyle? style = p.text.style;
      return mine.any((TextStyle r) => matchesRole(style, r)) &&
          !others.any((TextStyle r) => matchesRole(style, r));
    }).toList();
  }

  static String describeParagraph(RenderParagraph p) =>
      '« ${p.text.toPlainText()} » : famille '
      '${p.text.style?.fontFamily ?? 'aucune'}';

  /// Translation verticale rendue de [finder] : somme des translations de ses
  /// ancêtres (`Transform.translate`, `FractionalTranslation`).
  static double renderedTranslationY(Finder finder, {required String what}) {
    final List<Element> elements = finder.evaluate().toList();
    expect(elements, isNotEmpty, reason: '$what est introuvable');
    double dy = 0;
    RenderObject? child;
    RenderObject? render = elements.first.renderObject;
    while (render != null) {
      if (child != null &&
          (render is RenderTransform ||
              render is RenderFractionalTranslation)) {
        // Le déplacement de peinture que cet ancêtre applique à son enfant.
        final Matrix4 matrix = Matrix4.identity();
        (render as RenderBox).applyPaintTransform(child, matrix);
        dy += matrix.getTranslation().y;
      }
      child = render;
      render = render.parent;
    }
    return dy;
  }

  /// Les puces de statut affichées pour [status].
  static Finder chips(SceneStatus status) => find.byWidgetPredicate(
    (Widget w) => w is DsStatusChip && w.status == status,
  );

  /// Couleur du texte [label] dans la puce numéro [index] de [chips].
  static Color wordColor(WidgetTester tester, Finder chip, String label) {
    final Finder text = find.descendant(
      of: chip,
      matching: findTextIgnoringCase(label),
    );
    expect(
      text,
      findsOneWidget,
      reason: 'le mot « $label » est absent de la puce',
    );
    final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: text, matching: find.byType(RichText)).first,
    );
    final Color? color = paragraph.text.style?.color;
    expect(color, isNotNull, reason: 'mot « $label » sans couleur');
    return color!;
  }

  /// Couleurs de fond posées dans la puce (`DecoratedBox`, `ColoredBox`),
  /// de l'extérieur vers l'intérieur.
  static List<Color> fills(Finder chip) {
    final List<Color> colors = <Color>[];
    for (final Widget w
        in find
            .descendant(of: chip, matching: find.byWidgetPredicate((_) => true))
            .evaluate()
            .map((Element e) => e.widget)) {
      if (w is DecoratedBox) {
        final Decoration d = w.decoration;
        if (d is BoxDecoration && d.color != null) colors.add(d.color!);
      } else if (w is ColoredBox) {
        colors.add(w.color);
      }
    }
    return colors;
  }

  /// Le contenu de FontManifest.json (lu sous `runAsync` : vraie E/S).
  static Future<String> fontManifest(WidgetTester tester) async {
    final String? manifest = await tester.runAsync(
      () => rootBundle.loadString('FontManifest.json'),
    );
    return manifest ?? '';
  }
}
