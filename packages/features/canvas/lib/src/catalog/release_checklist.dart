import 'package:flutter/material.dart';
import 'package:genui/genui.dart' show CatalogItem;
import 'package:shared_design_system/shared_design_system.dart';

import 'bound_item.dart';
import 'text_metrics.dart';

/// `ReleaseChecklist` : lignes go/no-go, recommandation et statut de décision.
///
/// Le code `level` pilote la couleur des puces ; les libellés sont affichés
/// tels quels (jamais interprétés).
final CatalogItem releaseChecklistItem = boundCatalogItem<_Checklist>(
  name: 'ReleaseChecklist',
  description: 'Checklist go/no-go liée à /checklist.',
  parse: _Checklist.tryParse,
  build: (BuildContext context, _Checklist c, String _) =>
      _ChecklistView(checklist: c),
);

class _Item {
  const _Item(
    this.label,
    this.threshold,
    this.value,
    this.level,
    this.levelLabel,
  );

  final String label;
  final String threshold;
  final String value;
  final SceneStatus level;
  final String levelLabel;
}

class _Checklist {
  const _Checklist({
    required this.title,
    required this.items,
    required this.recommendationLevel,
    required this.recommendationLabel,
    required this.decisionStatus,
  });

  final String title;
  final List<_Item> items;
  final SceneStatus recommendationLevel;
  final String recommendationLabel;
  final String decisionStatus;

  static _Checklist? tryParse(Object raw) {
    if (raw is! Map) return null;
    final String? title = readString(raw, 'title');
    final String? decision = readString(raw, 'decisionStatus');
    final List<Map<Object?, Object?>>? rawItems = readMaps(raw, 'items');
    final Object? reco = raw['recommendation'];
    if (title == null || decision == null || rawItems == null || reco is! Map) {
      return null;
    }
    final SceneStatus? recoLevel = SceneStatus.fromCode(
      readString(reco, 'level'),
    );
    final String? recoLabel = readString(reco, 'label');
    if (recoLevel == null || recoLabel == null) return null;
    final List<_Item> items = <_Item>[];
    for (final Map<Object?, Object?> i in rawItems) {
      final String? label = readString(i, 'label');
      final String? threshold = readString(i, 'threshold');
      final String? value = readString(i, 'value');
      final SceneStatus? level = SceneStatus.fromCode(readString(i, 'level'));
      final String? levelLabel = readString(i, 'levelLabel');
      if (label == null ||
          threshold == null ||
          value == null ||
          level == null ||
          levelLabel == null) {
        return null;
      }
      items.add(_Item(label, threshold, value, level, levelLabel));
    }
    return _Checklist(
      title: title,
      items: items,
      recommendationLevel: recoLevel,
      recommendationLabel: recoLabel,
      decisionStatus: decision,
    );
  }
}

/// Statut de décision en pastille, jamais tronqué ; un changement de valeur
/// est mis en avant par une brève transition.
class _DecisionStatus extends StatelessWidget {
  const _DecisionStatus({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    key: const Key('decision-status'),
    duration: const Duration(milliseconds: 400),
    child: DsStatusChip(
      key: ValueKey<String>(status),
      status: null,
      label: status,
    ),
  );
}

/// Espace entre le titre, le statut et la recommandation, et entre deux
/// lignes d'en-tête quand elles ne tiennent pas côte à côte.
const double _headerGap = 16;

class _ChecklistView extends StatelessWidget {
  const _ChecklistView({required this.checklist});

  final _Checklist checklist;

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    return CellFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Le titre et les deux pastilles passent à la ligne suivante quand
          // la largeur ne suffit pas : aucun n'est tronqué.
          Wrap(
            spacing: _headerGap,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                checklist.title,
                style: theme.label.copyWith(color: theme.textPrimary),
              ),
              _DecisionStatus(status: checklist.decisionStatus),
              DsStatusChip(
                status: checklist.recommendationLevel,
                label: checklist.recommendationLabel,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(child: _ItemList(items: checklist.items)),
        ],
      ),
    );
  }
}

/// Remplissage vertical d'une ligne (1 px au-dessus et au-dessous).
const double _rowPadding = 2;

/// Espace entre les blocs d'une ligne de critère.
const double _gap = 8;

/// Espace entre le seuil et la valeur d'un critère présenté sur deux lignes.
const double _pairGap = 12;

double _lineHeight(TextStyle style) =>
    (style.fontSize ?? 24) * (style.height ?? 1);

double _chipHeight(SceneTheme theme) => _lineHeight(theme.label) + 12;

/// Liste des critères : jamais de troncature muette, les textes passent à la
/// ligne. Deux présentations, choisies pour toute la liste :
///
/// - **tableau** (cellule large) : libellé, seuil, valeur et puce sur une
///   seule ligne, colonnes alignées ;
/// - **deux lignes** (cellule étroite) : le libellé, puis le seuil et la
///   valeur dessous, la puce à droite ; la hauteur d'un critère est celle de
///   son texte réel.
///
/// Quand tous les critères ne tiennent pas, les bloquants (puis les à risque)
/// sont gardés en priorité, dans leur ordre d'origine, et la dernière ligne
/// annonce « + N autres critères ».
class _ItemList extends StatelessWidget {
  const _ItemList({required this.items});

  final List<_Item> items;

  static int _priority(_Item item) => switch (item.level) {
    SceneStatus.blocking => 0,
    SceneStatus.risk => 1,
    _ => 2,
  };

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final _Layout layout = _Layout.measure(
          context,
          theme,
          items,
          constraints.maxWidth,
        );
        final double moreHeight = _lineHeight(theme.body) + _rowPadding;
        final double budget = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : double.infinity;

        final double total = layout.heights.fold(
          0,
          (double a, double b) => a + b,
        );
        final List<int> kept = List<int>.generate(items.length, (int i) => i);
        bool showMore = false;
        if (total > budget) {
          // Ordre de priorité (niveau, puis rang d'origine) : on garde les
          // premiers critères qui tiennent avec la ligne « + N autres ».
          kept.sort((int a, int b) {
            final int byLevel = _priority(items[a])
                .compareTo(_priority(items[b]));
            return byLevel != 0 ? byLevel : a.compareTo(b);
          });
          double used = moreHeight;
          int count = 0;
          while (count < kept.length &&
              used + layout.heights[kept[count]] <= budget) {
            used += layout.heights[kept[count]];
            count++;
          }
          kept
            ..removeRange(count, kept.length)
            ..sort();
          // Si même la ligne d'annonce ne tient pas, rien à afficher.
          showMore = moreHeight <= budget;
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final int i in kept) layout.row(items[i]),
            if (showMore)
              SizedBox(
                height: moreHeight,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '+ ${items.length - kept.length} autres critères',
                    key: const Key('checklist-more'),
                    style: theme.body.copyWith(color: theme.textSecondary),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Présentation retenue pour la liste, avec la hauteur de chaque critère.
abstract class _Layout {
  const _Layout(this.heights);

  /// Hauteur de chaque critère, dans l'ordre de la liste.
  final List<double> heights;

  Widget row(_Item item);

  static _Layout measure(
    BuildContext context,
    SceneTheme theme,
    List<_Item> items,
    double maxWidth,
  ) {
    double widest(Iterable<String> texts, TextStyle style) {
      double max = 0;
      for (final String t in texts) {
        final double w = measureTextWidth(context, t, style);
        if (w > max) max = w;
      }
      // Marge d'arrondi pour ne pas déclencher un retour à la ligne sur un
      // demi-pixel.
      return max == 0 ? 0 : max.ceilToDouble() + 1;
    }

    final double chip =
        widest(items.map((_Item i) => i.levelLabel), theme.label) +
        2 * DsStatusChip.horizontalPadding;
    final double label = widest(items.map((_Item i) => i.label), theme.body);
    final double threshold = widest(
      items.map((_Item i) => i.threshold),
      theme.body,
    );
    final double value = widest(items.map((_Item i) => i.value), theme.body);
    final double tableWidth = label + threshold + value + chip + 3 * _gap;
    if (tableWidth <= maxWidth) {
      return _TableLayout(
        theme: theme,
        count: items.length,
        label: maxWidth.isFinite ? maxWidth - tableWidth + label : label,
        threshold: threshold,
        value: value,
        chip: chip,
      );
    }
    return _StackedLayout(
      context: context,
      theme: theme,
      items: items,
      chip: chip,
      textWidth: maxWidth - chip - _gap,
    );
  }
}

/// Tableau : une ligne de texte par critère, colonnes communes.
class _TableLayout extends _Layout {
  _TableLayout({
    required this.theme,
    required int count,
    required this.label,
    required this.threshold,
    required this.value,
    required this.chip,
  }) : super(<double>[
         for (int i = 0; i < count; i++)
           (_lineHeight(theme.body) > _chipHeight(theme)
                   ? _lineHeight(theme.body)
                   : _chipHeight(theme)) +
               _rowPadding,
       ]);

  final SceneTheme theme;
  final double label;
  final double threshold;
  final double value;
  final double chip;

  @override
  Widget row(_Item item) => Padding(
    padding: const EdgeInsets.symmetric(vertical: _rowPadding / 2),
    child: Row(
      children: <Widget>[
        SizedBox(
          width: label,
          child: Text(item.label, style: theme.body),
        ),
        const SizedBox(width: _gap),
        SizedBox(
          width: threshold,
          child: Text(
            item.threshold,
            style: theme.body.copyWith(color: theme.textSecondary),
          ),
        ),
        const SizedBox(width: _gap),
        SizedBox(
          width: value,
          child: Text(item.value, style: theme.body),
        ),
        const SizedBox(width: _gap),
        SizedBox(
          width: chip,
          child: Align(
            alignment: Alignment.centerRight,
            child: DsStatusChip(status: item.level, label: item.levelLabel),
          ),
        ),
      ],
    ),
  );
}

/// Deux lignes : libellé, puis seuil et valeur dessous ; puce à droite.
class _StackedLayout extends _Layout {
  _StackedLayout({
    required BuildContext context,
    required this.theme,
    required List<_Item> items,
    required this.chip,
    required this.textWidth,
  }) : super(<double>[
         for (final _Item item in items)
           _height(context, theme, item, textWidth),
       ]);

  final SceneTheme theme;
  final double chip;

  /// Largeur du bloc de texte (celle de la ligne moins la puce).
  final double textWidth;

  static double _height(
    BuildContext context,
    SceneTheme theme,
    _Item item,
    double textWidth,
  ) {
    final double label = measureTextHeight(
      context,
      item.label,
      theme.body,
      textWidth,
    );
    final double threshold = measureTextHeight(
      context,
      item.threshold,
      theme.body,
      textWidth,
    );
    final double value = measureTextHeight(
      context,
      item.value,
      theme.body,
      textWidth,
    );
    final double sideBySide =
        measureTextWidth(context, item.threshold, theme.body).ceilToDouble() +
        1 +
        _pairGap +
        measureTextWidth(context, item.value, theme.body).ceilToDouble() +
        1;
    final double pair = sideBySide <= textWidth
        ? (threshold > value ? threshold : value)
        : threshold + value;
    final double text = label + pair;
    final double chipH = _chipHeight(theme);
    return (text > chipH ? text : chipH) + _rowPadding;
  }

  @override
  Widget row(_Item item) => Padding(
    padding: const EdgeInsets.symmetric(vertical: _rowPadding / 2),
    child: Row(
      children: <Widget>[
        SizedBox(
          width: textWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(item.label, style: theme.body),
              Wrap(
                spacing: _pairGap,
                children: <Widget>[
                  Text(
                    item.threshold,
                    style: theme.body.copyWith(color: theme.textSecondary),
                  ),
                  Text(item.value, style: theme.body),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: _gap),
        SizedBox(
          width: chip,
          child: Align(
            alignment: Alignment.centerRight,
            child: DsStatusChip(status: item.level, label: item.levelLabel),
          ),
        ),
      ],
    ),
  );
}
