import 'package:flutter/widgets.dart';
import 'package:shared_design_system/shared_design_system.dart';
import 'package:widgetbook/widgetbook.dart';

part 'ds_neutral_state.stories.g.dart';

const meta = Meta(DsNeutralState.new);

final $Neutral = _Story(
  args: _Args(message: StringArg('Données indisponibles')),
);

/// L'état neutre prend la taille de son message : sans alignement, le
/// viewport (aux contraintes serrées) l'étirerait sur toute la cellule.
final defaults = _Defaults(
  setup: (context, child, args) =>
      Align(alignment: Alignment.topLeft, child: child),
);
