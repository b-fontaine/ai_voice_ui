import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'acte3_harness.dart';
import 'session_harness.dart';

/// État et aides partagés par les scénarios d'interruption vocale et de retour
/// au clic (spec 011).
class InterruptionHarness {
  InterruptionHarness._();

  /// Nombre de requêtes `POST /canvas/actions` relevé par le scénario.
  static int? notedActionRequests;

  static void reset() => notedActionRequests = null;

  /// Valeur sémantique de l'orbe (`repos`, `parole`, `Écoute`, `Interrompue`…).
  /// Exige l'arbre sémantique actif (contexte « horloge virtuelle »).
  static String orbState(WidgetTester tester) =>
      tester.getSemantics(find.byKey(const Key('voice-orb'))).value;

  /// Le bouton d'action [id] de la Barre d'actions.
  static Finder actionButton(String id) => Acte3Harness.button(id);

  /// Le texte [text] du statut de décision, dans la surface `checklist`.
  static Finder checklistText(String text) => find.descendant(
    of: find.byKey(const Key('surface-checklist')),
    matching: find.text(text),
  );

  /// Dernier transport créé (le seul de la session courante).
  static dynamic get lastTransport => SessionHarness.transports.created.last;

  /// Vérifie qu'un `Text` est affiché sans troncature ni débordement : il
  /// tient sur sa largeur naturelle, sans points de suspension, et son
  /// rectangle reste dans [container].
  static void expectFullyVisible(
    WidgetTester tester,
    Finder text,
    Finder container,
  ) {
    expect(text, findsWidgets, reason: 'le texte est absent');
    final paragraph = tester.renderObject<RenderParagraph>(text.first);
    expect(
      paragraph.didExceedMaxLines,
      isFalse,
      reason: 'le texte dépasse son nombre de lignes maximal (tronqué)',
    );
    final natural = TextPainter(
      text: paragraph.text,
      textDirection: paragraph.textDirection,
      textScaler: paragraph.textScaler,
    )..layout();
    expect(
      paragraph.size.width,
      greaterThanOrEqualTo(natural.width - 0.5),
      reason:
          'le texte est tronqué : ${paragraph.size.width} px disponibles '
          'pour ${natural.width} px nécessaires',
    );
    natural.dispose();
    final rect = tester.getRect(text.first);
    final bounds = tester.getRect(container.first);
    expect(
      bounds.inflate(0.5).contains(rect.topLeft) &&
          bounds.inflate(0.5).contains(rect.bottomRight),
      isTrue,
      reason: 'le texte déborde de sa surface : $rect hors de $bounds',
    );
    expect(tester.takeException(), isNull, reason: "débordement signalé");
  }
}
