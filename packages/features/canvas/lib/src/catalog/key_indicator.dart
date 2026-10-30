import 'package:flutter/material.dart';
import 'package:genui/genui.dart'
    show BoundObject, CatalogItem, CatalogItemContext;
import 'package:json_schema_builder/json_schema_builder.dart' show S, Schema;
import 'package:shared_design_system/shared_design_system.dart';

/// Champs obligatoires de l'objet `/kpi` (contrat `genesis` v1).
///
/// Le champ optionnel `comparison` (acte 2) est toléré et ignoré.
const List<String> keyIndicatorRequiredFields = <String>[
  'label',
  'value',
  'trend',
  'threshold',
  'status',
  'statusLabel',
];

/// `KeyIndicator` : un indicateur clé (libellé, valeur, tendance, seuil, statut).
///
/// L'objet est lu avec `BoundObject` (jamais `dataContext.subscribe` dans le
/// `widgetBuilder`, A1b). Trois états distincts : sans données (objet absent),
/// neutre (objet incomplet ou de mauvais type, RG-10), affichage complet.
final CatalogItem keyIndicatorItem = CatalogItem(
  name: 'KeyIndicator',
  dataSchema: S.object(
    description: 'Indicateur clé lié à /kpi.',
    properties: <String, Schema>{
      'data': S.object(
        description: 'Liaison au data model : {"path": "/kpi"}.',
        properties: <String, Schema>{'path': S.string()},
        required: <String>['path'],
      ),
    },
    required: <String>['data'],
  ),
  widgetBuilder: (CatalogItemContext ctx) {
    final Object data = ctx.data;
    return BoundObject(
      dataContext: ctx.dataContext,
      value: data is Map ? data['data'] : null,
      builder: (BuildContext context, Object? object) =>
          _KeyIndicatorView(surfaceId: ctx.surfaceId, object: object),
    );
  },
);

class _KeyIndicatorView extends StatelessWidget {
  const _KeyIndicatorView({required this.surfaceId, required this.object});

  final String surfaceId;
  final Object? object;

  @override
  Widget build(BuildContext context) {
    final Object? raw = object;
    if (raw == null) return _NoData(key: Key('nodata-$surfaceId'));
    final _Kpi? kpi = _Kpi.tryParse(raw);
    if (kpi == null) {
      return SizedBox.expand(
        child: DsNeutralState(key: Key('neutral-$surfaceId')),
      );
    }
    return _Complete(kpi: kpi);
  }
}

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
    String? text(String field) {
      final Object? v = raw[field];
      return v is String ? v : null;
    }

    final String? label = text('label');
    final String? value = text('value');
    final String? trend = text('trend');
    final String? threshold = text('threshold');
    final String? statusLabel = text('statusLabel');
    final SceneStatus? status = SceneStatus.fromCode(text('status'));
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

/// Cellule reconnaissable sans valeur : composants reçus, données pas encore.
class _NoData extends StatelessWidget {
  const _NoData({super.key});

  @override
  Widget build(BuildContext context) => SizedBox.expand(
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: SceneTheme.of(context).surface,
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );
}

class _Complete extends StatelessWidget {
  const _Complete({required this.kpi});

  final _Kpi kpi;

  @override
  Widget build(BuildContext context) {
    final SceneTheme theme = SceneTheme.of(context);
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
        ),
      ),
    );
  }
}
