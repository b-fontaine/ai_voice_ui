import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:shared_core/shared_core.dart' show AppClock;

import 'keys.dart';

/// Horloge de l'app virtuelle (frontière « temps », pdr-0038) : elle n'avance
/// que sur ordre du scénario, ce qui donne au journal des écarts exacts, sans
/// attente réelle.
class VirtualClock implements AppClock {
  int _unixMs = 1761800000000;

  @override
  int nowUnixMs() => _unixMs;

  void advance(Duration duration) => _unixMs += duration.inMilliseconds;
}

/// Clés de la zone « Rejeu » (contrat d'interface de la spec 010).
abstract final class ReplayKeys {
  static const Key play = Key('replay-play');
  static const Key restart = Key('replay-restart');
  static const Key slider = Key('replay-slider');
  static const Key direct = Key('replay-direct');
  static const Key actIndicator = Key('act-indicator');

  /// Pastille de la vitesse [speed] (`0.25`, `0.5`, `1`, `1.5`, `2`).
  static Key speed(num speed) =>
      Key('replay-speed-${speed == speed.truncate() ? speed.toInt() : speed}');
}

/// État et aides partagés par les scénarios de l'acte 4 (spec 010).
///
/// Réglages de la spec : l'app les reçoit par injection (`GenesisConfig`), mais
/// les steps s'appuient sur les valeurs par défaut de pdr-0066 (plafond d'écart
/// 3 s, pas 100 ms, vitesse initiale 1×) et les recopient ici pour calculer
/// leurs attentes.
class Acte4Harness {
  Acte4Harness._();

  static const Duration replayMaxGap = Duration(seconds: 3);
  static const Duration tick = Duration(milliseconds: 100);

  static VirtualClock clock = VirtualClock();

  /// Écart entre deux surfaces de l'acte 1 joué en direct.
  static Duration spacing = const Duration(seconds: 2);

  static Map<String, Object?>? notedRender;
  static double? notedPosition;
  static int? notedRequests;
  static final List<Duration> durations = <Duration>[];
  static TestGesture? gesture;

  /// Surfaces que les scénarios savent reconnaître dans le canevas.
  static const List<String> knownSurfaces = <String>[
    ...AcceptanceKeys.act1Surfaces,
    'actions',
  ];

  static void reset() {
    clock = VirtualClock();
    spacing = const Duration(seconds: 2);
    notedRender = null;
    notedPosition = null;
    notedRequests = null;
    durations.clear();
    gesture = null;
    releaseSemantics();
  }

  static SemanticsHandle? _semantics;

  /// Active l'arbre sémantique (libellés « Lecture » / « Pause »). Le banc de
  /// test exige de le libérer avant la fin du test : [releaseSemantics].
  static void ensureSemantics(WidgetTester tester) {
    _semantics ??= tester.ensureSemantics();
  }

  static void releaseSemantics() {
    _semantics?.dispose();
    _semantics = null;
  }

  // --- Temps simulé ---------------------------------------------------------

  /// Fait avancer le temps simulé de [total] par pas du lecteur : jamais de
  /// `pumpAndSettle` pendant une lecture (un minuteur périodique ne s'arrête
  /// jamais).
  static Future<void> elapse(WidgetTester tester, Duration total) async {
    var done = Duration.zero;
    while (done < total) {
      final step = total - done < tick ? total - done : tick;
      await tester.pump(step);
      done += step;
    }
  }

  static Duration seconds(num value) =>
      Duration(milliseconds: (value * 1000).round());

  /// Deux cadres de durée nulle : laisse passer les microtâches, la barrière
  /// d'un tour de boucle du lecteur et les Blocs. `pump()` sans argument
  /// n'écoule aucun minuteur (même de durée nulle) : `Duration.zero` est
  /// nécessaire pour que la barrière du lecteur s'exécute.
  static Future<void> settle(WidgetTester tester) async {
    await tester.pump(Duration.zero);
    await tester.pump(Duration.zero);
  }

  // --- Zone Rejeu -----------------------------------------------------------

  static Finder _required(Key key) {
    final finder = find.byKey(key);
    expect(
      finder,
      findsOneWidget,
      reason: 'widget $key introuvable : la zone Rejeu ne l\'expose pas',
    );
    return finder;
  }

  /// `true` si la commande [key] est activable.
  static bool isEnabled(WidgetTester tester, Key key) {
    final finder = _required(key);
    Finder inside(bool Function(Widget) test) => find.descendant(
      of: finder,
      matching: find.byWidgetPredicate(test),
      matchRoot: true,
    );
    final buttons = inside((w) => w is ButtonStyleButton);
    if (buttons.evaluate().isNotEmpty) {
      return tester.widget<ButtonStyleButton>(buttons.first).enabled;
    }
    final chips = inside(
      (w) => w is ChoiceChip || w is ActionChip || w is FilterChip,
    );
    if (chips.evaluate().isNotEmpty) {
      final chip = tester.widget(chips.first);
      return switch (chip) {
        ChoiceChip(:final onSelected) => onSelected != null,
        FilterChip(:final onSelected) => onSelected != null,
        ActionChip(:final onPressed) => onPressed != null,
        _ => false,
      };
    }
    final inks = inside((w) => w is InkWell);
    expect(
      inks,
      findsWidgets,
      reason:
          'la commande $key n\'est ni un bouton ni une pastille ni un InkWell',
    );
    return tester.widget<InkWell>(inks.first).onTap != null;
  }

  /// Appuie sur la commande [key] ; échoue si elle est absente ou inactive.
  static Future<void> press(WidgetTester tester, Key key) async {
    final finder = _required(key);
    expect(
      isEnabled(tester, key),
      isTrue,
      reason: 'la commande $key est inactive (onPressed: null)',
    );
    await tester.tap(finder);
    await settle(tester);
  }

  /// Libellé sémantique du bouton Lecture/Pause.
  static String playLabel(WidgetTester tester) {
    final finder = _required(ReplayKeys.play);
    return tester.getSemantics(finder).label;
  }

  /// Position du curseur, en pourcentage de sa course.
  static double position(WidgetTester tester) {
    final sliders = find.descendant(
      of: _required(ReplayKeys.slider),
      matching: find.byType(Slider),
      matchRoot: true,
    );
    expect(
      sliders,
      findsOneWidget,
      reason: 'replay-slider doit être un Slider',
    );
    final slider = tester.widget<Slider>(sliders);
    final span = slider.max - slider.min;
    expect(span, greaterThan(0), reason: 'le curseur n\'a pas de course');
    return (slider.value - slider.min) / span * 100;
  }

  /// Le rejeu est à sa dernière image : curseur au bout, bouton « Lecture ».
  static bool isEnded(WidgetTester tester) =>
      position(tester) >= 99.9 && playLabel(tester).contains('Lecture');

  // --- Canevas, panneau, étagère -------------------------------------------

  /// Surfaces connues présentes dans le canevas.
  static Set<String> displayedSurfaces() => <String>{
    for (final id in knownSurfaces)
      if (find.byKey(AcceptanceKeys.surface(id)).evaluate().isNotEmpty) id,
  };

  static List<String> textsUnder(Finder root) => find
      .descendant(of: root, matching: find.byType(Text))
      .evaluate()
      .map((e) {
        final text = e.widget as Text;
        return text.data ?? text.textSpan?.toPlainText() ?? '';
      })
      .toList();

  static final RegExp _timeOfDay = RegExp(r'^\d{2}:\d{2}:\d{2}$');

  /// Photographie du rendu : surfaces (textes, phases), moteurs de rendu,
  /// étagère et panneau du protocole **hors horodatage** (l'heure affichée est
  /// celle du rejeu, A7).
  static Map<String, Object?> snapshot(WidgetTester tester) {
    final surfaces = <String, Object?>{};
    for (final id in knownSurfaces) {
      final cell = find.byKey(AcceptanceKeys.surface(id));
      if (cell.evaluate().isEmpty) continue;
      surfaces[id] = <String, Object?>{
        'texts': textsUnder(cell),
        'skeleton': find
            .descendant(
              of: cell,
              matching: find.byKey(AcceptanceKeys.skeleton(id)),
            )
            .evaluate()
            .isNotEmpty,
        'neutral': find
            .descendant(
              of: cell,
              matching: find.byKey(AcceptanceKeys.neutral(id)),
            )
            .evaluate()
            .isNotEmpty,
        'highlight': find
            .byKey(AcceptanceKeys.highlight(id))
            .evaluate()
            .isNotEmpty,
      };
    }
    return <String, Object?>{
      'surfaces': surfaces,
      'engines': find.byType(Surface).evaluate().length,
      'shelf': textsUnder(find.byKey(AcceptanceKeys.catalogShelf)),
      'panel': textsUnder(find.byKey(AcceptanceKeys.protocolPanel))
          .where((t) => !_timeOfDay.hasMatch(t))
          .toList(),
    };
  }

  /// Nombre de messages annoncé par le panneau replié (« 6 messages »).
  static int panelCount(WidgetTester tester) {
    final pattern = RegExp(r'^(\d+) messages?$');
    for (final text in textsUnder(find.byKey(AcceptanceKeys.protocolPanel))) {
      final match = pattern.firstMatch(text);
      if (match != null) return int.parse(match.group(1)!);
    }
    fail('le panneau du protocole replié doit annoncer « n messages »');
  }
}
