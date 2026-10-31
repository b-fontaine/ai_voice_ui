import 'package:flutter/widgets.dart';
import 'package:widgetbook/widgetbook.dart';

import 'genesis_components.dart';
import 'genesis_surface_host.dart';

part 'release_checklist.stories.g.dart';

const meta = Meta(ReleaseChecklist.new);

/// L'exemple complet du contrat.
final $Data = _Story(
  args: _Args(
    state: EnumArg(
      GenesisSurfaceState.data,
      values: GenesisSurfaceState.values,
    ),
  ),
);

/// Surface créée, aucune donnée reçue (RG-02).
final $NoData = _Story(
  args: _Args(
    state: EnumArg(
      GenesisSurfaceState.noData,
      values: GenesisSurfaceState.values,
    ),
  ),
);

/// Données invalides : état neutre (RG-10).
final $Neutral = _Story(
  args: _Args(
    state: EnumArg(
      GenesisSurfaceState.neutral,
      values: GenesisSurfaceState.values,
    ),
  ),
);

final defaults = _Defaults(
  setup: (context, child, args) => genesisStorySetup(child),
);
