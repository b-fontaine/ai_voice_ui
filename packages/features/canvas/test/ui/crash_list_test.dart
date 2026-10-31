import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

import '../support/catalog_harness.dart';

Finder _rowByRank(int rank) => find.byKey(Key('crash-row-$rank'));

Finder _allRows() => find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith('crash-row-'),
);

CatalogHarness _harness({Size size = const Size(940, 255)}) =>
    CatalogHarness('crashes', 'global', variant: 'crashlist', size: size);

Map<String, dynamic> _item(int rank, String label) => <String, dynamic>{
  'rank': rank,
  'label': label,
  'platform': 'Android',
  'volume': 10,
  'sessions': 9,
};

void main() {
  defineCommonStateTests(
    component: 'CrashList',
    surface: 'crashes',
    fixtureName: 'global',
    variant: 'crashlist',
    completeText: 'Principaux crashs',
    badValues: <String, Object?>{
      'items est une chaîne': <String, Object>{
        'title': 'T',
        'items': 'cinq lignes',
      },
      'ligne sans libellé': <String, Object>{
        'title': 'T',
        'items': <Object>[
          <String, Object>{
            'rank': 1,
            'platform': 'iOS',
            'volume': 1,
            'sessions': 1,
          },
        ],
      },
      'libellé de mauvais type': <String, Object>{
        'title': 'T',
        'items': <Object>[
          <String, Object>{
            'rank': 1,
            'label': 42,
            'platform': 'iOS',
            'volume': 1,
            'sessions': 1,
          },
        ],
      },
      'volume de mauvais type': <String, Object>{
        'title': 'T',
        'items': <Object>[
          <String, Object>{
            'rank': 1,
            'label': 'L',
            'platform': 'iOS',
            'volume': 'beaucoup',
            'sessions': 1,
          },
        ],
      },
      'ligne qui n est pas un objet': <String, Object>{
        'title': 'T',
        'items': <Object>['texte'],
      },
    },
  );

  testWidgets(
    'cinq lignes : rang, libellé, plateforme, volume (sessions non affichées)',
    (tester) async {
      final h = _harness();
      await h.pump(tester);
      await h.sendFixtureTo(tester, 3);

      expect(h.inCell(find.text('Principaux crashs · 3.4')), findsOneWidget);
      expect(h.inCell(_allRows()), findsNWidgets(5));
      for (var rank = 1; rank <= 5; rank++) {
        expect(h.inCell(_rowByRank(rank)), findsOneWidget);
        expect(
          find.descendant(
            of: _rowByRank(rank),
            matching: find.byKey(Key('crash-label-$rank')),
          ),
          findsOneWidget,
        );
      }
      final first = _rowByRank(1);
      Finder inFirst(String text) =>
          find.descendant(of: first, matching: find.text(text));
      expect(inFirst('1'), findsOneWidget);
      expect(
        inFirst('Plantage à la validation du panier (3-D Secure 2)'),
        findsOneWidget,
      );
      expect(inFirst('Android'), findsOneWidget);
      expect(inFirst('371'), findsOneWidget);
      expect(find.textContaining('sess.'), findsNothing);
      // Ordre de lecture : les rangs se suivent de haut en bas.
      for (var rank = 1; rank < 5; rank++) {
        expect(
          tester.getTopLeft(_rowByRank(rank + 1)).dy,
          greaterThan(tester.getTopLeft(_rowByRank(rank)).dy),
        );
      }
      expect(h.engineErrors, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('les lignes sont des descendantes simples de la cellule', (
    tester,
  ) async {
    final h = _harness();
    await h.pump(tester);
    await h.sendFixtureTo(tester, 3);

    expect(
      find.descendant(
        of: find.byKey(const Key('surface-crashes')),
        matching: _allRows(),
      ),
      findsNWidgets(5),
    );
    expect(find.byKey(const Key('nodata-crashes')), findsNothing);
    expect(find.byKey(const Key('skeleton-crashes')), findsNothing);
  });

  testWidgets('sans données : aucune ligne ; neutre : aucune ligne', (
    tester,
  ) async {
    final h = _harness();
    await h.pump(tester);
    await h.sendFixtureTo(tester, 1);
    expect(find.byKey(const Key('skeleton-crashes')), findsOneWidget);
    expect(_allRows(), findsNothing);
    await h.send(tester, h.fixture[1]);
    expect(find.byKey(const Key('nodata-crashes')), findsOneWidget);
    expect(_allRows(), findsNothing);
    await h.sendData(tester, <String, Object>{'title': 'T', 'items': 'x'});
    expect(find.byKey(const Key('neutral-crashes')), findsOneWidget);
    expect(_allRows(), findsNothing);
  });

  testWidgets('liste vide : titre seul, aucune ligne, pas d état neutre', (
    tester,
  ) async {
    final h = _harness();
    await h.pump(tester);
    await h.sendFixtureTo(tester, 2);
    await h.sendData(tester, <String, Object>{
      'title': 'Principaux crashs · 3.4',
      'items': <Object>[],
    });
    expect(find.byKey(const Key('neutral-crashes')), findsNothing);
    expect(h.inCell(find.text('Principaux crashs · 3.4')), findsOneWidget);
    expect(_allRows(), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('libellé de 60 caractères : une ligne puis ellipse', (
    tester,
  ) async {
    final h = _harness(size: const Size(940, 255));
    await h.pump(tester);
    await h.sendFixtureTo(tester, 2);
    await h.sendData(tester, <String, Object>{
      'title': 'T',
      'items': <Object>[_item(1, 'très long ' * 30)],
    });

    final label = find.byKey(const Key('crash-label-1'));
    final text = tester.widget<Text>(label);
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: label, matching: find.byType(RichText)).first,
    );
    expect(paragraph.didExceedMaxLines, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('couleurs et styles viennent du thème de scène', (tester) async {
    final h = _harness();
    await h.pump(tester);
    await h.sendFixtureTo(tester, 3);
    const theme = SceneTheme.dark();
    final label = tester.widget<Text>(find.byKey(const Key('crash-label-1')));
    expect(label.style?.color, theme.textPrimary);
    expect(label.style?.fontSize, theme.body.fontSize);
    final platform = tester.widget<Text>(
      find.descendant(of: _rowByRank(1), matching: find.text('Android')),
    );
    expect(platform.style?.color, theme.textSecondary);
  });
}
