import 'package:flutter/widgets.dart';
import 'package:shared_design_system/shared_design_system.dart';
import 'package:widgetbook/widgetbook.dart';

import 'ds_story_setup.dart';

part 'ds_beacon.stories.g.dart';

const meta = Meta(DsBeacon.new);

const SceneTheme _theme = SceneTheme.dark();

/// Phase de repos (animations coupées) : le point seul, sans halo figé.
final $Dot = _Story(
  args: _Args(
    color: Arg.fixed(_theme.blockingForeground),
    size: DoubleArg(8),
    child: Arg.fixed(null),
  ),
);

final defaults = _Defaults(
  setup: (context, child, args) =>
      dsStorySetup(Align(alignment: Alignment.topLeft, child: child)),
);
