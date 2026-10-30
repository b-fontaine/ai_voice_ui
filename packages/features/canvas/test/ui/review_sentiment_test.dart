import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/catalog_harness.dart';

final Finder excerptRows = find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey &&
      '${(w.key as ValueKey).value}'.startsWith('review-excerpt-'),
);

void main() {
  defineCommonStateTests(
    component: 'ReviewSentiment',
    surface: 'reviews',
    fixtureName: 'reviews',
    completeText: 'Sentiment des avis',
    badValues: <String, Object?>{
      'deux extraits seulement': <String, Object>{
        'title': 'T',
        'count': 10,
        'positivePct': 50,
        'negativePct': 50,
        'average': 3.0,
        'excerpts': <Object>[
          <String, Object>{'stars': 1, 'platform': 'iOS', 'text': 'a'},
          <String, Object>{'stars': 2, 'platform': 'iOS', 'text': 'b'},
        ],
      },
      'extrait incomplet': <String, Object>{
        'title': 'T',
        'count': 10,
        'positivePct': 50,
        'negativePct': 50,
        'average': 3.0,
        'excerpts': <Object>[
          <String, Object>{'stars': 1, 'platform': 'iOS', 'text': 'a'},
          <String, Object>{'stars': 2, 'platform': 'iOS'},
          <String, Object>{'stars': 3, 'platform': 'iOS', 'text': 'c'},
        ],
      },
      'étoiles hors 1 à 5': <String, Object>{
        'title': 'T',
        'count': 10,
        'positivePct': 50,
        'negativePct': 50,
        'average': 3.0,
        'excerpts': <Object>[
          <String, Object>{'stars': 9, 'platform': 'iOS', 'text': 'a'},
          <String, Object>{'stars': 2, 'platform': 'iOS', 'text': 'b'},
          <String, Object>{'stars': 3, 'platform': 'iOS', 'text': 'c'},
        ],
      },
      'count de mauvais type': <String, Object>{
        'title': 'T',
        'count': 'beaucoup',
        'positivePct': 50,
        'negativePct': 50,
        'average': 3.0,
        'excerpts': <Object>[],
      },
    },
  );

  testWidgets('acte 1 : chiffres, répartition et 3 extraits', (tester) async {
    final h = CatalogHarness('reviews', 'reviews');
    await h.pump(tester);
    await h.sendFixtureTo(tester, 3);

    expect(h.inCell(find.text('Sentiment des avis')), findsOneWidget);
    expect(h.inCell(find.textContaining('1164')), findsOneWidget);
    expect(h.inCell(find.textContaining('76 %')), findsOneWidget);
    expect(h.inCell(find.textContaining('24 %')), findsOneWidget);
    expect(h.inCell(find.textContaining('4,0')), findsOneWidget);
    expect(h.inCell(excerptRows), findsNWidgets(3));
    expect(
      h.inCell(find.textContaining("L'app se ferme dès que je valide")),
      findsOneWidget,
    );
    expect(h.inCell(find.byKey(const Key('review-split-bar'))), findsOneWidget);
    expect(h.engineErrors, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('extrait trop long : ellipse sur une ligne bornée', (
    tester,
  ) async {
    final h = CatalogHarness('reviews', 'reviews');
    await h.pump(tester);
    await h.sendFixtureTo(tester, 2);
    final data = cloneJson(h.data);
    (data['excerpts'] as List)[0]['text'] = 'très long ' * 80;
    await h.sendData(tester, data);

    final texts = tester.widgetList<Text>(
      h.inCell(find.descendant(of: excerptRows, matching: find.byType(Text))),
    );
    expect(texts, isNotEmpty);
    for (final t in texts) {
      expect(t.maxLines, isNotNull);
      expect(t.overflow, TextOverflow.ellipsis);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('le champ comparison est toléré et ignoré', (tester) async {
    final h = CatalogHarness('reviews', 'reviews');
    await h.pump(tester);
    await h.sendFixtureTo(tester, 2);
    await h.sendData(tester, <String, dynamic>{
      ...h.data,
      'comparison': <String, String>{
        'label': 'Version précédente',
        'value': '90 %',
        'delta': '+2',
      },
    });
    expect(find.byKey(const Key('neutral-reviews')), findsNothing);
    expect(h.inCell(find.text('Sentiment des avis')), findsOneWidget);
    expect(find.textContaining('Version précédente'), findsNothing);
  });
}
