import 'package:flutter/material.dart';
import 'package:genui/genui.dart'
    show BoundObject, CatalogItem, CatalogItemContext;
import 'package:json_schema_builder/json_schema_builder.dart' show S, Schema;
import 'package:shared_design_system/shared_design_system.dart';

/// Fabrique un `CatalogItem` du catalogue `genesis` lié à l'objet [path].
///
/// L'objet est lu avec `BoundObject` (jamais `dataContext.subscribe` dans le
/// `widgetBuilder`, A1b). Trois états distincts :
/// - objet absent : cellule « sans données » (`nodata-<surfaceId>`) ;
/// - objet incomplet, de mauvais type ou de statut hors enum : état neutre
///   (`neutral-<surfaceId>`, RG-10), jamais d'exception ;
/// - objet valide ([parse] renvoie une valeur) : [build].
CatalogItem boundCatalogItem<T extends Object>({
  required String name,
  required String path,
  required String description,
  required T? Function(Object raw) parse,
  required Widget Function(BuildContext context, T value) build,
}) => CatalogItem(
  name: name,
  dataSchema: S.object(
    description: description,
    properties: <String, Schema>{
      'data': S.object(
        description: 'Liaison au data model : {"path": "$path"}.',
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
      builder: (BuildContext context, Object? object) {
        if (object == null) {
          return NoDataCell(key: Key('nodata-${ctx.surfaceId}'));
        }
        final T? value = _safeParse(parse, object);
        if (value == null) {
          return SizedBox.expand(
            child: DsNeutralState(key: Key('neutral-${ctx.surfaceId}')),
          );
        }
        return build(context, value);
      },
    );
  },
);

/// Un analyseur qui lèverait une exception donne l'état neutre (RG-10).
T? _safeParse<T extends Object>(T? Function(Object raw) parse, Object raw) {
  try {
    return parse(raw);
  } on Object {
    return null;
  }
}

/// Cellule reconnaissable sans valeur : composants reçus, données pas encore.
class NoDataCell extends StatelessWidget {
  const NoDataCell({super.key});

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

/// Fond arrondi commun aux cellules complètes.
class CellFrame extends StatelessWidget {
  const CellFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox.expand(
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: SceneTheme.of(context).surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );
}

/// Lecture typée d'un champ d'un objet JSON (`null` si absent ou de mauvais type).
String? readString(Map<Object?, Object?> map, String field) {
  final Object? v = map[field];
  return v is String ? v : null;
}

/// Nombre fini (`int` ou `double`), sinon `null`.
double? readNumber(Map<Object?, Object?> map, String field) {
  final Object? v = map[field];
  return v is num && v.isFinite ? v.toDouble() : null;
}

/// Entier (un `double` sans partie décimale est accepté), sinon `null`.
int? readInt(Map<Object?, Object?> map, String field) {
  final Object? v = map[field];
  if (v is int) return v;
  if (v is double && v.isFinite && v == v.truncateToDouble()) return v.toInt();
  return null;
}

/// Liste d'objets (`Map`), sinon `null`.
List<Map<Object?, Object?>>? readMaps(Map<Object?, Object?> map, String field) {
  final Object? v = map[field];
  if (v is! List) return null;
  final List<Map<Object?, Object?>> out = <Map<Object?, Object?>>[];
  for (final Object? e in v) {
    if (e is! Map) return null;
    out.add(e);
  }
  return out;
}
