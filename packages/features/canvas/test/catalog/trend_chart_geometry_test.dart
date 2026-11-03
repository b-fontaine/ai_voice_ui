import 'dart:ui';

import 'package:feature_canvas/src/catalog/trend_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dérivations du graphique de tendance (pdr-0088 F4) : série courante,
/// franchissement strict, abscisse interpolée, polygones, valeur de tête,
/// annotation. Fonctions pures, testées en table.
const List<String> _days = <String>['J1', 'J2', 'J3', 'J4', 'J5', 'J6', 'J7'];

/// Android de l'acte 1 : 0,50 à J4 est le seuil, donc pas encore franchi.
const List<double> _android = <double>[0.3, 0.33, 0.4, 0.5, 0.62, 0.73, 0.84];
const List<double> _ios = <double>[0.22, 0.2, 0.21, 0.19, 0.21, 0.2, 0.19];
const List<double> _android33 = <double>[
  0.3,
  0.28,
  0.29,
  0.27,
  0.31,
  0.29,
  0.29,
];

void main() {
  group('série comparée / courante', () {
    for (final (String name, bool compared) in <(String, bool)>[
      ('Android 3.3', true),
      ('iOS 3.3', true),
      ('Android 3.4', false),
      ('iOS', false),
      ('Android', false),
      ('3.30', false),
    ]) {
      test('« $name » : comparée = $compared', () {
        expect(isComparedSeries(name), compared);
      });
    }
  });

  group('premier franchissement strict du seuil', () {
    for (final (String what, List<double> points, int? index)
        in <(String, List<double>, int?)>[
          (
            'Android acte 1 : 0,50 à J4 n\'est pas un franchissement',
            _android,
            4,
          ),
          ('iOS ne franchit jamais', _ios, null),
          ('égal au seuil partout : aucun', <double>[0.5, 0.5, 0.5], null),
          ('dès le premier point', <double>[0.7, 0.8], 0),
          ('un seul point au-dessus', <double>[0.1, 0.9], 1),
          ('liste vide', <double>[], null),
        ]) {
      test(what, () {
        expect(firstBreachIndex(points, 0.5), index);
      });
    }
  });

  group('abscisse interpolée du croisement', () {
    test('Android : le croisement tombe exactement sur J4 (indice 3)', () {
      expect(breachCrossingX(_android, 0.5), closeTo(3, 1e-9));
    });

    test('croisement au milieu de deux jours', () {
      // 0,4 à l\'indice 1, 0,6 à l\'indice 2, seuil 0,5 : indice 1,5.
      expect(breachCrossingX(<double>[0.2, 0.4, 0.6], 0.5), closeTo(1.5, 1e-9));
    });

    test('au-dessus dès le premier point : indice 0', () {
      expect(breachCrossingX(<double>[0.7, 0.8], 0.5), 0);
    });

    test('aucun franchissement : null', () {
      expect(breachCrossingX(_ios, 0.5), isNull);
    });
  });

  group('polygone de la zone de franchissement', () {
    test('Android : du croisement au dernier jour, entre série et seuil', () {
      expect(breachPolygon(_android, 0.5), const <TrendPoint>[
        TrendPoint(3, 0.5),
        TrendPoint(4, 0.62),
        TrendPoint(5, 0.73),
        TrendPoint(6, 0.84),
        TrendPoint(6, 0.5),
      ]);
    });

    test('croisement interpolé : le polygone commence au croisement', () {
      final List<TrendPoint> polygon = breachPolygon(<double>[
        0.2,
        0.4,
        0.6,
      ], 0.5);
      expect(polygon.first.x, closeTo(1.5, 1e-9));
      expect(polygon.first.y, 0.5);
      expect(polygon.last, const TrendPoint(2, 0.5));
    });

    test('sans franchissement : vide', () {
      expect(breachPolygon(_ios, 0.5), isEmpty);
    });
  });

  group('polygone de la zone sous la série', () {
    test('suit la série puis ferme par la base', () {
      expect(areaPolygon(<double>[0.3, 0.5, 0.4]), const <TrendPoint>[
        TrendPoint(0, 0.3),
        TrendPoint(1, 0.5),
        TrendPoint(2, 0.4),
        TrendPoint(2, 0),
        TrendPoint(0, 0),
      ]);
    });

    test('moins de deux points : vide', () {
      expect(areaPolygon(<double>[0.3]), isEmpty);
      expect(areaPolygon(<double>[]), isEmpty);
    });
  });

  group('annotation et valeur de tête', () {
    test('acte 1 : « ▲ seuil franchi dès J5 »', () {
      expect(breachCallout(_days, _android, 0.5), '▲ seuil franchi dès J5');
    });

    test('absente sans franchissement', () {
      expect(breachCallout(_days, _ios, 0.5), isNull);
      expect(breachCallout(_days, _android33, 0.5), isNull);
    });

    test('dérivée des libellés de jours de la donnée', () {
      expect(
        breachCallout(<String>['lun', 'mar'], <double>[0.1, 0.9], 0.5),
        '▲ seuil franchi dès mar',
      );
    });

    test('valeur de tête : dernier point, deux décimales, virgule', () {
      expect(formatPct(_android.last), '0,84 %');
      expect(formatPct(0.5), '0,50 %');
      expect(formatPct(0.2), '0,20 %');
      expect(formatPct(1), '1,00 %');
    });
  });

  group('série sur laquelle portent zone et annotation (F4)', () {
    TrendFocus? focus(List<(String, List<double>)> series) =>
        trendFocus(<({String name, List<double> points})>[
          for (final (String n, List<double> p) in series) (name: n, points: p),
        ], 0.5);

    test('acte 1 : iOS ne franchit pas, Android oui : Android', () {
      final TrendFocus? f = focus(<(String, List<double>)>[
        ('iOS', _ios),
        ('Android', _android),
      ]);
      expect(f?.seriesIndex, 1);
      expect(f?.breachIndex, 4);
    });

    test('deux séries courantes qui franchissent : la première', () {
      final TrendFocus? f = focus(<(String, List<double>)>[
        ('iOS', <double>[0.4, 0.6]),
        ('Android', _android),
      ]);
      expect(f?.seriesIndex, 0);
      expect(f?.breachIndex, 1);
    });

    test('acte 2 : la 3.3 comparée n\'est jamais la série suivie', () {
      final TrendFocus? f = focus(<(String, List<double>)>[
        ('Android 3.3', <double>[0.9, 0.9]),
        ('Android 3.4', _android),
      ]);
      expect(f?.seriesIndex, 1);
    });

    test('une seule série courante sans franchissement : elle, sans zone de '
        'franchissement', () {
      final TrendFocus? f = focus(<(String, List<double>)>[('iOS 3.4', _ios)]);
      expect(f?.seriesIndex, 0);
      expect(f?.breachIndex, isNull);
    });

    test('deux séries courantes sans franchissement : aucune', () {
      expect(
        focus(<(String, List<double>)>[('iOS', _ios), ('Android', _ios)]),
        isNull,
      );
    });

    test('aucune série courante : aucune', () {
      expect(
        focus(<(String, List<double>)>[('Android 3.3', _android33)]),
        isNull,
      );
    });
  });

  group('graduations de l\'axe des valeurs', () {
    test('quatre graduations jusqu\'à yMax, texte à deux décimales', () {
      expect(trendTicks(1.0), <double>[0.25, 0.5, 0.75, 1.0]);
      expect(trendTicks(1.0).map(formatTick), <String>[
        '0,25',
        '0,50',
        '0,75',
        '1,00',
      ]);
      expect(trendTicks(0.8).map(formatTick), <String>[
        '0,20',
        '0,40',
        '0,60',
        '0,80',
      ]);
    });
  });

  group('zone du tracé', () {
    test('à droite des graduations, au-dessus des jours', () {
      final Rect? plot = trendPlotRect(
        size: const Size(600, 200),
        axisLabelWidth: 30,
        firstDayWidth: 14,
        lastDayWidth: 14,
        tickHeight: 12,
        dayHeight: 12,
      );
      expect(plot, const Rect.fromLTRB(38, 6, 592, 180));
    });

    test('le premier jour ne sort pas : le libellé large décale le tracé', () {
      final Rect plot = trendPlotRect(
        size: const Size(600, 200),
        axisLabelWidth: 10,
        firstDayWidth: 100,
        lastDayWidth: 100,
        tickHeight: 12,
        dayHeight: 12,
      )!;
      expect(plot.left, 50);
      expect(plot.right, 550);
    });

    test('région trop petite : pas de tracé', () {
      expect(
        trendPlotRect(
          size: const Size(40, 20),
          axisLabelWidth: 30,
          firstDayWidth: 14,
          lastDayWidth: 14,
          tickHeight: 12,
          dayHeight: 12,
        ),
        isNull,
      );
    });
  });
}
