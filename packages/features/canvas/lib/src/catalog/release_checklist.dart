import 'package:flutter/material.dart';
import 'package:genui/genui.dart' show CatalogItem;
import 'package:shared_design_system/shared_design_system.dart';

import 'bound_item.dart';

/// `ReleaseChecklist` : lignes go/no-go, recommandation et statut de décision.
///
/// Le code `level` pilote la couleur des puces ; les libellés sont affichés
/// tels quels (jamais interprétés).
final CatalogItem releaseChecklistItem = boundCatalogItem<_Checklist>(
  name: 'ReleaseChecklist',
  path: '/checklist',
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
          // Les lignes en trop sont rognées, jamais de débordement.
          Expanded(
            child: ClipRect(
              child: ListView(
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: <Widget>[
                  for (final _Item item in checklist.items)
                    _ItemRow(item: item),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final _Item item;

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 5,
            child: Text(
              item.label,
              style: theme.body,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              item.threshold,
              style: theme.body.copyWith(color: theme.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              item.value,
              style: theme.body,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          DsStatusChip(status: item.level, label: item.levelLabel),
        ],
      ),
    );
  }
}
