import 'package:flutter/widgets.dart';
import 'package:shared_design_system/shared_design_system.dart';
import 'package:widgetbook/widgetbook.dart';

import 'ds_story_setup.dart';

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
      dsStorySetup(Align(alignment: Alignment.topLeft, child: child)),
);

/// Les quatre statuts côte à côte : ok (avec ✓), risque, bloquant (point
/// battant, immobile ici) et neutre. Le `setup` remplace la puce par la
/// rangée : le `builder` généré doit rendre un `DsStatusChip`.
final $AllStatuses = _Story(
  setup: (context, child, args) => dsStorySetup(
    const Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        DsStatusChip(status: SceneStatus.ok, label: 'Prêt'),
        DsStatusChip(status: SceneStatus.risk, label: 'À surveiller'),
        DsStatusChip(status: SceneStatus.blocking, label: 'Bloquant'),
        DsStatusChip(status: null, label: 'Inconnu'),
      ],
    ),
  ),
);
