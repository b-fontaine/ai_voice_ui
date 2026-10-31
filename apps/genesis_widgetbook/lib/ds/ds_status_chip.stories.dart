import 'package:flutter/widgets.dart';
import 'package:shared_design_system/shared_design_system.dart';
import 'package:widgetbook/widgetbook.dart';

part 'ds_status_chip.stories.g.dart';

const meta = Meta(DsStatusChip.new);

final $Ok = _Story(
  args: _Args(
    status: NullableEnumArg(SceneStatus.ok, values: SceneStatus.values),
    label: StringArg('Prêt'),
  ),
);

final $Risk = _Story(
  args: _Args(
    status: NullableEnumArg(SceneStatus.risk, values: SceneStatus.values),
    label: StringArg('À surveiller'),
  ),
);

final $Blocking = _Story(
  args: _Args(
    status: NullableEnumArg(SceneStatus.blocking, values: SceneStatus.values),
    label: StringArg('Bloquant'),
  ),
);

/// Statut inconnu ou absent : style neutre.
final $Neutral = _Story(
  args: _Args(status: Arg.fixed(null), label: StringArg('Inconnu')),
);

/// La puce prend la taille de son libellé : sans alignement, le viewport (aux
/// contraintes serrées) l'étirerait sur toute la cellule.
final defaults = _Defaults(
  setup: (context, child, args) =>
      Align(alignment: Alignment.topLeft, child: child),
);
