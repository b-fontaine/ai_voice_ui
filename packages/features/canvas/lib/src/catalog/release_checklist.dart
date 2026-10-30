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
  build: (BuildContext context, _Checklist c) => _ChecklistView(checklist: c),
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
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  checklist.title,
                  style: theme.label.copyWith(color: theme.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Flexible(
                child: Text(
                  checklist.decisionStatus,
                  style: theme.body.copyWith(color: theme.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 16),
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

/// Liste des critères : jamais de troncature muette. Quand tous ne tiennent
/// pas, les critères bloquants (puis à risque) sont gardés en priorité, dans
/// leur ordre d'origine, et la dernière ligne annonce « + N autres critères ».
class _ItemList extends StatelessWidget {
  const _ItemList({required this.items});

  final List<_Item> items;

  static int _priority(_Item item) => switch (item.level) {
    SceneStatus.blocking => 0,
    SceneStatus.risk => 1,
    _ => 2,
  };

  /// Hauteur d'une ligne : la plus haute de la ligne de texte et de la puce,
  /// plus le remplissage vertical de la ligne.
  static double _rowHeight(SceneTheme theme) {
    final double text = (theme.body.fontSize ?? 24) * (theme.body.height ?? 1);
    final double chip =
        (theme.label.fontSize ?? 24) * (theme.label.height ?? 1) + 12;
    return (text > chip ? text : chip) + 4;
  }

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    final double rowH = _rowHeight(theme);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int capacity = constraints.hasBoundedHeight
            ? (constraints.maxHeight / rowH).floor()
            : items.length;
        final bool all = items.length <= capacity;
        final int shown = all
            ? items.length
            : (capacity > 1 ? capacity - 1 : 0);
        final List<int> kept = List<int>.generate(items.length, (int i) => i);
        if (!all) {
          // Tri par priorité de niveau (départage par rang d'origine), puis
          // retour à l'ordre d'origine parmi les lignes gardées.
          kept.sort((int a, int b) {
            final int byLevel = _priority(items[a])
                .compareTo(_priority(items[b]));
            return byLevel != 0 ? byLevel : a.compareTo(b);
          });
          kept
            ..removeRange(shown, kept.length)
            ..sort();
        }
        final int hidden = items.length - shown;
        final _Columns columns = _Columns.measure(context, theme, <_Item>[
          for (final int i in kept) items[i],
        ], constraints.maxWidth);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final int i in kept)
              SizedBox(
                height: rowH,
                child: _ItemRow(item: items[i], columns: columns),
              ),
            if (!all && capacity > 0)
              SizedBox(
                height: rowH,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '+ $hidden autres critères',
                    key: const Key('checklist-more'),
                    style: theme.body.copyWith(color: theme.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Largeurs des colonnes seuil / valeur / puce, communes à toutes les lignes
/// pour qu'elles restent alignées. La valeur passe en priorité (elle cite la
/// 3.3 à l'acte 2 et ne doit jamais être coupée) ; le libellé prend le reste
/// et porte l'ellipse.
class _Columns {
  const _Columns({
    required this.threshold,
    required this.value,
    required this.chip,
  });

  static const double gap = 12;

  final double threshold;
  final double value;
  final double chip;

  factory _Columns.measure(
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
      // Marge d'arrondi pour ne pas déclencher l'ellipse sur un demi-pixel.
      return max == 0 ? 0 : max.ceilToDouble() + 1;
    }

    // Puce : libellé en style `label` plus le remplissage horizontal (2 x 16).
    final double chip =
        widest(items.map((_Item i) => i.levelLabel), theme.label) + 32;
    final double available =
        (maxWidth.isFinite ? maxWidth : double.maxFinite) - chip - 3 * gap;
    final double value = _clamp(
      widest(items.map((_Item i) => i.value), theme.body),
      available,
    );
    final double threshold = _clamp(
      widest(items.map((_Item i) => i.threshold), theme.body),
      (available - value) / 2,
    );
    return _Columns(threshold: threshold, value: value, chip: chip);
  }

  static double _clamp(double wanted, double limit) =>
      wanted < limit ? wanted : (limit > 0 ? limit : 0);
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.columns});

  final _Item item;
  final _Columns columns;

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              item.label,
              style: theme.body,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: _Columns.gap),
          SizedBox(
            width: columns.threshold,
            child: Text(
              item.threshold,
              style: theme.body.copyWith(color: theme.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: _Columns.gap),
          SizedBox(
            width: columns.value,
            child: Text(
              item.value,
              style: theme.body,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: _Columns.gap),
          SizedBox(
            width: columns.chip,
            child: Align(
              alignment: Alignment.centerRight,
              child: DsStatusChip(status: item.level, label: item.levelLabel),
            ),
          ),
        ],
      ),
    );
  }
}
