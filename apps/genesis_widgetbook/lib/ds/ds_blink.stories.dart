import 'package:flutter/widgets.dart';
import 'package:shared_design_system/shared_design_system.dart';
import 'package:widgetbook/widgetbook.dart';

import 'ds_story_setup.dart';

part 'ds_blink.stories.g.dart';

const meta = Meta(DsBlink.new);

/// Phase de repos (animations coupées) : l'enfant reste plein, jamais figé à
/// demi-teinte.
final $Solid = _Story(args: _Args(child: Arg.fixed(const Text('Curseur ▍'))));

final defaults = _Defaults(
  setup: (context, child, args) =>
      dsStorySetup(Align(alignment: Alignment.topLeft, child: child)),
);
