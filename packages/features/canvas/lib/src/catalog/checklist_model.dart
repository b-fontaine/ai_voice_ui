import 'package:shared_design_system/shared_design_system.dart'
    show SceneStatus;

import 'bound_item.dart';

/// Critère d'une checklist.
class ChecklistItem {
  const ChecklistItem(
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

/// Données de `ReleaseChecklist`, lues du modèle de données.
class ChecklistData {
  const ChecklistData({
    required this.title,
    required this.items,
    required this.recommendationLevel,
    required this.recommendationLabel,
    required this.decisionStatus,
  });

  final String title;
  final List<ChecklistItem> items;
  final SceneStatus recommendationLevel;
  final String recommendationLabel;
  final String decisionStatus;

  static ChecklistData? tryParse(Object raw) {
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
    final List<ChecklistItem> items = <ChecklistItem>[];
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
      items.add(ChecklistItem(label, threshold, value, level, levelLabel));
    }
    return ChecklistData(
      title: title,
      items: items,
      recommendationLevel: recoLevel,
      recommendationLabel: recoLabel,
      decisionStatus: decision,
    );
  }
}
