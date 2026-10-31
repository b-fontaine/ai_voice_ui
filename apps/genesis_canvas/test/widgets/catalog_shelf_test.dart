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
import 'package:testing_real_fonts/testing_real_fonts.dart';

import '../support/contrast.dart';

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

ValidatedEnvelope _delete(String surface) => ValidatedEnvelope(
  raw: <String, Object?>{
    'version': 'v0.9',
    'deleteSurface': <String, Object?>{'surfaceId': surface},
  },
  verdict: const ValidationAccepted(),
);

void main() {
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

  Future<void> pumpShelf(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
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
    );
    bloc.add(CatalogShelfSourceSubscribed(envelopes.stream));
    await tester.pump();
  }

  Future<void> receive(WidgetTester tester, ValidatedEnvelope e) async {
    envelopes.add(e);
    await tester.pump();
    await tester.pump();
  }

  Finder item(String component) => find.byKey(Key('shelf-$component'));

  // L'état n'est plus écrit : il est porté par l'icône et la sémantique.
  Finder iconOf(String component) =>
      find.descendant(of: item(component), matching: find.byType(Icon));

  Finder stateOf(String component, String state) => find.descendant(
    of: item(component),
    matching: find.byWidgetPredicate(
      (w) =>
          w is Icon &&
          w.icon ==
              (state == 'utilisé'
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked),
    ),
  );

  const all = <String>[
    'KeyIndicator',
    'TrendChart',
    'ReviewSentiment',
    'ReleaseChecklist',
    'ActionBar',
    'CrashList',
  ];

  testWidgets('au départ : « 0 / 6 utilisés » et six composants inutilisés', (
    tester,
  ) async {
    await pumpShelf(tester);

    expect(find.byKey(const Key('catalog-shelf')), findsOneWidget);
    expect(find.text('CATALOGUE ·'), findsOneWidget);
    expect(find.text('0 / 6 utilisés'), findsOneWidget);
    for (final component in all) {
      expect(item(component), findsOneWidget, reason: component);
      expect(stateOf(component, 'inutilisé'), findsOneWidget);
      expect(stateOf(component, 'utilisé'), findsNothing);
      expect(
        find.descendant(of: item(component), matching: find.text(component)),
        findsOneWidget,
      );
      expect(iconOf(component), findsOneWidget, reason: component);
    }
  });

  testWidgets('polices réelles : six noms entiers, aucun paragraphe tronqué, '
      'texte de 24 px au moins, en 6/6 comme en 0/6', (tester) async {
    await loadRealFonts(alsoAs: const <String>['Roboto']);
    await pumpShelf(tester);
    expect(paragraphsTruncated(tester), isEmpty, reason: '0 / 6');
    for (final component in all) {
      expect(find.text(component), findsOneWidget, reason: component);
    }

    for (final (surface, component) in all.indexed) {
      envelopes.add(_update('s$surface', component));
    }
    await tester.pump();
    await tester.pump();
    expect(find.text('6 / 6 utilisés'), findsOneWidget);
    expect(paragraphsTruncated(tester), isEmpty, reason: '6 / 6');
    expect(tester.takeException(), isNull);
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      final size = text.style?.fontSize ?? 0;
      expect(size, greaterThanOrEqualTo(24), reason: text.data);
    }
  });

  testWidgets('deux rangées de trois puces dans 900 x 140 px', (tester) async {
    await loadRealFonts(alsoAs: const <String>['Roboto']);
    await pumpShelf(tester);

    final tops = <double>{
      for (final component in all) tester.getTopLeft(item(component)).dy,
    };
    expect(tops, hasLength(2));
    expect(
      tester.getSize(find.byKey(const Key('catalog-shelf'))),
      const Size(900, 140),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('l\'état est porté par deux icônes distinctes, une par puce, '
      'et par la sémantique', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpShelf(tester);
    await receive(tester, _update('kpi', 'KeyIndicator'));

    final used = tester.widget<Icon>(iconOf('KeyIndicator')).icon;
    final unused = tester.widget<Icon>(iconOf('TrendChart')).icon;
    expect(used, isNot(unused));
    for (final component in all) {
      expect(iconOf(component), findsOneWidget, reason: component);
    }
    expect(
      tester.getSemantics(item('KeyIndicator')).label,
      allOf(contains('KeyIndicator'), contains('utilisé')),
    );
    expect(
      tester.getSemantics(item('KeyIndicator')).label,
      isNot(contains('inutilisé')),
    );
    expect(
      tester.getSemantics(item('TrendChart')).label,
      allOf(contains('TrendChart'), contains('inutilisé')),
    );
    semantics.dispose();
  });

  testWidgets('l\'icône de chaque état contraste 4,5:1 avec sa puce', (
    tester,
  ) async {
    await pumpShelf(tester);
    await receive(tester, _update('kpi', 'KeyIndicator'));
    const theme = SceneTheme.dark();

    for (final (component, background) in <(String, Color)>[
      ('KeyIndicator', theme.okBackground),
      ('TrendChart', theme.neutralBackground),
    ]) {
      final Color? icon = tester.widget<Icon>(iconOf(component)).color;
      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: item(component),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final Color fill = (box.decoration as BoxDecoration).color ?? background;
      expect(fill, background, reason: component);
      expect(icon, isNotNull, reason: component);
      expect(contrast(icon!, fill), greaterThanOrEqualTo(4.5));
    }
  });

  testWidgets('un composant déduit d\'un updateComponents devient « utilisé », '
      'les autres restent « inutilisé »', (tester) async {
    await pumpShelf(tester);
    await receive(tester, _update('kpi', 'KeyIndicator'));
    await receive(tester, _update('trend', 'TrendChart'));

    expect(find.text('2 / 6 utilisés'), findsOneWidget);
    expect(stateOf('KeyIndicator', 'utilisé'), findsOneWidget);
    expect(stateOf('TrendChart', 'utilisé'), findsOneWidget);
    expect(stateOf('KeyIndicator', 'inutilisé'), findsNothing);
    expect(stateOf('ReviewSentiment', 'inutilisé'), findsOneWidget);
    expect(stateOf('ActionBar', 'inutilisé'), findsOneWidget);
    expect(stateOf('CrashList', 'inutilisé'), findsOneWidget);
  });

  testWidgets('une surface supprimée libère son composant', (tester) async {
    await pumpShelf(tester);
    await receive(tester, _update('kpi', 'KeyIndicator'));
    expect(stateOf('KeyIndicator', 'utilisé'), findsOneWidget);

    await receive(tester, _delete('kpi'));

    expect(stateOf('KeyIndicator', 'inutilisé'), findsOneWidget);
    expect(find.text('0 / 6 utilisés'), findsOneWidget);
  });

  testWidgets('la remise à vide éteint tout', (tester) async {
    await pumpShelf(tester);
    await receive(tester, _update('kpi', 'KeyIndicator'));
    await receive(tester, _update('trend', 'TrendChart'));

    bloc.add(const CatalogShelfCleared());
    await tester.pump();
    await tester.pump();

    expect(find.text('0 / 6 utilisés'), findsOneWidget);
    expect(stateOf('KeyIndicator', 'inutilisé'), findsOneWidget);
  });

  testWidgets('un message refusé n\'allume rien', (tester) async {
    await pumpShelf(tester);
    await receive(
      tester,
      ValidatedEnvelope(
        raw: _update('kpi', 'Column').raw,
        verdict: const ValidationRejected(ValidationCodes.componentNotAllowed),
      ),
    );

    expect(find.text('0 / 6 utilisés'), findsOneWidget);
  });
}
