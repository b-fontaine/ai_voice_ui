import 'package:entity_catalog/entity_catalog.dart' show GenesisContract;
import 'package:flutter/material.dart';
import 'package:genui/genui.dart'
    show BoundObject, CatalogItem, CatalogItemContext;
import 'package:json_schema_builder/json_schema_builder.dart' show S, Schema;
import 'package:shared_design_system/shared_design_system.dart';

/// Fabrique un `CatalogItem` du catalogue `genesis` lié à l'objet du contrat
/// (`GenesisContract.boundPathOf(name)`, source unique du chemin).
///
/// L'objet est lu avec `BoundObject` (jamais `dataContext.subscribe` dans le
/// `widgetBuilder`, A1b). Trois états distincts :
/// - objet absent : cellule « sans données » (`nodata-<surfaceId>`) ;
/// - objet incomplet, de mauvais type ou de statut hors enum : état neutre
///   (`neutral-<surfaceId>`, RG-10), jamais d'exception ;
/// - objet valide ([parse] renvoie une valeur) : [build], qui reçoit aussi
///   l'identifiant de la surface du contexte de rendu.
CatalogItem boundCatalogItem<T extends Object>({
  required String name,
  required String description,
  required T? Function(Object raw) parse,
  required Widget Function(BuildContext context, T value, String surfaceId)
  build,
}) {
  final String path =
      GenesisContract.boundPathOf(name) ??
      (throw ArgumentError.value(name, 'name', 'composant sans liaison'));
  return CatalogItem(
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
            return _ValueFade(
              state: _BoundState.noData,
              child: NoDataCell(key: Key('nodata-${ctx.surfaceId}')),
            );
          }
          final T? value = _safeParse(parse, object);
          if (value == null) {
            return _ValueFade(
              state: _BoundState.neutral,
              child: SizedBox.expand(
                child: DsNeutralState(key: Key('neutral-${ctx.surfaceId}')),
              ),
            );
          }
          return _ValueFade(
            state: _BoundState.data,
            child: build(context, value, ctx.surfaceId),
          );
        },
      );
    },
  );
}

/// État d'une cellule liée : la clé de l'animation est l'état, jamais la
/// valeur.
enum _BoundState { noData, neutral, data }

/// Fondu des valeurs (150 ms, [SceneMotion.value]) au seul passage « sans
/// données » vers « données ».
///
/// Le même widget, à la même place, enveloppe les trois états : son `State`
/// survit aux mises à jour du data model, donc un `updateDataModel` de l'acte 2
/// ne rejoue rien et ne recrée pas le `State` du contenu (pdr-0064 D1, S-02).
/// Une cellule montée directement avec ses données (restauration) est
/// pleinement visible. La durée suit `SceneMotionScope` : nulle si les
/// animations sont coupées, divisée par la vitesse du rejeu.
class _ValueFade extends StatefulWidget {
  const _ValueFade({required this.state, required this.child});

  final _BoundState state;
  final Widget child;

  @override
  State<_ValueFade> createState() => _ValueFadeState();
}

class _ValueFadeState extends State<_ValueFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: SceneMotion.value,
    value: 1,
  );

  @override
  void didUpdateWidget(_ValueFade oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != _BoundState.noData ||
        widget.state != _BoundState.data) {
      return;
    }
    final Duration duration = SceneMotionScope.of(context)
        .durationFor(SceneMotion.value);
    _animation.duration = duration;
    if (duration == Duration.zero) {
      _animation.value = 1;
    } else {
      _animation.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _animation,
    child: widget.child,
    builder: (BuildContext context, Widget? child) => Opacity(
      opacity: SceneMotion.curve.transform(_animation.value),
      child: child,
    ),
  );
}

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
  const CellFrame({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;

  /// Marge intérieure (la Barre d'actions réduit la marge verticale pour tenir
  /// dans son bandeau de 72 px).
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => SizedBox.expand(
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: SceneTheme.of(context).surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(padding: padding, child: child),
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

/// Texte de la ligne de comparaison (`<label> : <value> · <delta>`) de
/// l'objet [raw] ; `null` si `comparison` est absent ou incomplet (un champ
/// `label`/`value`/`delta` manquant ou de mauvais type) : la ligne est alors
/// omise sans toucher au reste du composant (pdr-0064 D7, RG-10).
String? readComparisonText(Map<Object?, Object?> raw) {
  final Object? comparison = raw['comparison'];
  if (comparison is! Map) return null;
  final String? label = readString(comparison, 'label');
  final String? value = readString(comparison, 'value');
  final String? delta = readString(comparison, 'delta');
  if (label == null || value == null || delta == null) return null;
  return '$label : $value \u00B7 $delta';
}

/// Ligne de comparaison : un seul `Text` portant la clé [key]
/// (`comparison-<surface>`), en couleur neutre (jamais une couleur de statut),
/// sur une ligne.
Text comparisonLine(
  BuildContext context, {
  required Key key,
  required String text,
}) {
  final SceneTheme theme = SceneTheme.of(context);
  return Text(
    text,
    key: key,
    style: theme.body.copyWith(color: theme.textSecondary),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  );
}
