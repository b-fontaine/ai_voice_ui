import 'package:flutter/material.dart';
import 'package:genui/genui.dart' show CatalogItem;
import 'package:shared_design_system/shared_design_system.dart';

import 'bound_item.dart';

/// `KeyIndicator` : un indicateur clé (libellé, valeur, tendance, seuil, statut).
final CatalogItem keyIndicatorItem = boundCatalogItem<_Kpi>(
  name: 'KeyIndicator',
  description: 'Indicateur clé lié à /kpi.',
  parse: _Kpi.tryParse,
  build: (BuildContext context, _Kpi kpi) => _Complete(kpi: kpi),
);

/// Objet `/kpi` validé.
class _Kpi {
  const _Kpi({
    required this.label,
    required this.value,
    required this.trend,
    required this.threshold,
    required this.status,
    required this.statusLabel,
  });

  final String label;
  final String value;
  final String trend;
  final String threshold;
  final SceneStatus status;
  final String statusLabel;

  /// `null` si l'objet n'est pas une `Map` ou si un champ requis manque, a un
  /// mauvais type ou un statut hors `ok|risk|blocking`.
  static _Kpi? tryParse(Object raw) {
    if (raw is! Map) return null;
    final String? label = readString(raw, 'label');
    final String? value = readString(raw, 'value');
    final String? trend = readString(raw, 'trend');
    final String? threshold = readString(raw, 'threshold');
    final String? statusLabel = readString(raw, 'statusLabel');
    final SceneStatus? status = SceneStatus.fromCode(readString(raw, 'status'));
    if (label == null ||
        value == null ||
        trend == null ||
        threshold == null ||
        statusLabel == null ||
        status == null) {
      return null;
    }
    return _Kpi(
      label: label,
      value: value,
      trend: trend,
      threshold: threshold,
      status: status,
      statusLabel: statusLabel,
    );
  }
}

class _Complete extends StatelessWidget {
  const _Complete({required this.kpi});

  final _Kpi kpi;

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    return CellFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            kpi.label,
            style: theme.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Row(
            children: <Widget>[
              Flexible(
                child: Text(
                  kpi.value,
                  style: theme.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 16),
              DsStatusChip(status: kpi.status, label: kpi.statusLabel),
            ],
          ),
          Row(
            children: <Widget>[
              Flexible(
                child: Text(
                  kpi.trend,
                  style: theme.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 24),
              Flexible(
                child: Text(
                  kpi.threshold,
                  style: theme.body.copyWith(color: theme.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
