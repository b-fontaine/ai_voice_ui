import 'dart:async';

import 'package:entity_catalog/entity_catalog.dart';
import 'package:feature_catalog_shelf/feature_catalog_shelf.dart';
import 'package:flutter/material.dart' show Icon, Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart' hide testWidgets;
import 'package:flutter_test/flutter_test.dart'
    as flutter_test
    show testWidgets;
import 'package:genesis_canvas/widgets/catalog_shelf/catalog_shelf.dart';
import 'package:shared_design_system/shared_design_system.dart';

/// Puces du catalogue (`.gc-chip`, FR-06, T33) : 30 points de haut, rayon
/// `sm`, états inutilisé / utilisé, lueur `gc-flash` à la première utilisation.
ValidatedEnvelope _update(String surface, String component) =>
    ValidatedEnvelope(
      raw: <String, Object?>{
        'version': 'v0.9',
        'updateComponents': <String, Object?>{
          'surfaceId': surface,
          'components': <Object?>[
            <String, Object?>{'id': 'root', 'component': component},
          ],
        },
      },
      verdict: const ValidationAccepted(),
    );

void main() {
  const SceneTheme theme = SceneTheme.dark();
  late CatalogShelfBloc bloc;
  late StreamController<ValidatedEnvelope> envelopes;

  void testWidgets(
    String description,
    Future<void> Function(WidgetTester tester) body,
  ) => flutter_test.testWidgets(description, (tester) async {
    bloc = CatalogShelfBloc();
    envelopes = StreamController<ValidatedEnvelope>.broadcast();
    await body(tester);
    await tester.pumpWidget(const SizedBox());
    unawaited(envelopes.close());
    unawaited(bloc.close());
    await tester.pump();
  });

  Future<void> pumpShelf(
    WidgetTester tester, {
    bool motionDisabled = false,
  }) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SceneMotionScope(
          disabled: motionDisabled,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 900,
              height: 140,
              child: BlocProvider<CatalogShelfBloc>.value(
                value: bloc,
                child: const CatalogShelf(),
              ),
            ),
          ),
        ),
      ),
    );
    bloc.add(CatalogShelfSourceSubscribed(envelopes.stream));
    await tester.pump();
  }

  Future<void> receive(WidgetTester tester, String component) async {
    envelopes.add(_update('s-$component', component));
    await tester.pump();
    await tester.pump();
  }

  Finder chip(String component) => find.byKey(Key('shelf-$component'));

  BoxDecoration decoration(WidgetTester tester, String component) =>
      tester
              .widget<DecoratedBox>(
                find
                    .descendant(
                      of: chip(component),
                      matching: find.byType(DecoratedBox),
                    )
                    .first,
              )
              .decoration
          as BoxDecoration;

  bool glows(WidgetTester tester, String component) =>
      (decoration(tester, component).boxShadow ?? const <BoxShadow>[]).any(
        (BoxShadow s) => s.color.a > 0,
      );

  TextStyle textStyle(WidgetTester tester, String component) => tester
      .widget<Text>(
        find.descendant(of: chip(component), matching: find.text(component)),
      )
      .style!;

  testWidgets('une puce fait 30 points de haut, rayon sm, bordure de 1 point', (
    tester,
  ) async {
    await pumpShelf(tester);
    await receive(tester, 'KeyIndicator');

    for (final String component in <String>['KeyIndicator', 'CrashList']) {
      expect(tester.getSize(chip(component)).height, 30, reason: component);
      final BoxDecoration d = decoration(tester, component);
      expect(d.borderRadius, SceneRadius.borderSm, reason: component);
      expect((d.border! as Border).top.width, 1, reason: component);
    }
  });

  testWidgets('inutilisée : fond surface-100, bordure line, texte ink-muted '
      'en micro.chip, carré vide', (tester) async {
    await pumpShelf(tester);

    final BoxDecoration d = decoration(tester, 'CrashList');
    expect(d.color, theme.surface);
    expect((d.border! as Border).top.color, theme.line);
    final TextStyle style = textStyle(tester, 'CrashList');
    expect(style.color, theme.textSecondary, reason: 'jamais ink-faint (F12)');
    expect(style.fontSize, theme.micro.chip.fontSize);
    expect(style.fontFamily, theme.micro.chip.fontFamily);
    final Icon icon = tester.widget<Icon>(
      find.descendant(of: chip('CrashList'), matching: find.byType(Icon)),
    );
    expect(icon.icon, Icons.square_outlined);
    expect(icon.color, theme.textSecondary);
    expect(glows(tester, 'CrashList'), isFalse);
  });

  testWidgets('utilisée : fond signal-ghost, bordure signal à 33 %, texte '
      'signal, carré plein', (tester) async {
    await pumpShelf(tester, motionDisabled: true);
    await receive(tester, 'KeyIndicator');

    final BoxDecoration d = decoration(tester, 'KeyIndicator');
    expect(d.color, theme.signalGhost);
    final Color border = (d.border! as Border).top.color;
    expect(border.r, closeTo(theme.accent.r, 0.01));
    expect(border.g, closeTo(theme.accent.g, 0.01));
    expect(border.b, closeTo(theme.accent.b, 0.01));
    expect(border.a, closeTo(0x55 / 0xFF, 0.01));
    expect(textStyle(tester, 'KeyIndicator').color, theme.accent);
    final Icon icon = tester.widget<Icon>(
      find.descendant(of: chip('KeyIndicator'), matching: find.byType(Icon)),
    );
    expect(icon.icon, Icons.square);
    expect(icon.color, theme.accent);
  });

  testWidgets('les six puces tiennent en trois colonnes de largeur égale', (
    tester,
  ) async {
    await pumpShelf(tester);

    final List<double> lefts = <double>[
      for (final String c in <String>[
        'KeyIndicator',
        'TrendChart',
        'ReviewSentiment',
      ])
        tester.getTopLeft(chip(c)).dx,
    ];
    expect(lefts[1], greaterThan(lefts[0]));
    expect(lefts[2], greaterThan(lefts[1]));
    expect(
      tester.getSize(chip('KeyIndicator')).width,
      tester.getSize(chip('ReviewSentiment')).width,
    );
    expect(
      tester.getTopLeft(chip('ReleaseChecklist')).dx,
      tester.getTopLeft(chip('KeyIndicator')).dx,
      reason: 'seconde rangée alignée sur la première colonne',
    );
  });

  testWidgets('première utilisation : la puce a une lueur signal qui monte '
      'puis s\'éteint en 1,2 s', (tester) async {
    await pumpShelf(tester);
    expect(glows(tester, 'ActionBar'), isFalse);

    await receive(tester, 'ActionBar');
    expect(
      glows(tester, 'ActionBar'),
      isTrue,
      reason: '0 % : ombre nulle signal',
    );
    await tester.pump(const Duration(milliseconds: 480));
    expect(glows(tester, 'ActionBar'), isTrue, reason: 'pic à 40 %');
    final BoxShadow peak = decoration(
      tester,
      'ActionBar',
    ).boxShadow!.firstWhere((BoxShadow s) => s.color.a > 0);
    expect(peak.color.r, closeTo(theme.accent.r, 0.01));
    expect(glows(tester, 'KeyIndicator'), isFalse, reason: 'autres puces');

    await tester.pump(const Duration(milliseconds: 1200));
    expect(glows(tester, 'ActionBar'), isFalse);
    expect(
      tester.hasRunningAnimations,
      isFalse,
      reason: 'aucune boucle : la lueur ne joue qu\'une fois',
    );
  });

  testWidgets('une puce déjà utilisée ne rejoue pas la lueur quand une autre '
      's\'allume', (tester) async {
    await pumpShelf(tester);
    await receive(tester, 'KeyIndicator');
    await tester.pump(const Duration(milliseconds: 1500));
    expect(glows(tester, 'KeyIndicator'), isFalse);

    await receive(tester, 'TrendChart');
    await tester.pump(const Duration(milliseconds: 300));

    expect(glows(tester, 'TrendChart'), isTrue);
    expect(glows(tester, 'KeyIndicator'), isFalse);
  });

  testWidgets('sous disableAnimations : état final d\'emblée, sans lueur', (
    tester,
  ) async {
    await pumpShelf(tester, motionDisabled: true);

    await receive(tester, 'ActionBar');

    expect(glows(tester, 'ActionBar'), isFalse);
    expect(decoration(tester, 'ActionBar').color, theme.signalGhost);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
