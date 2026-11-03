import 'package:flutter/widgets.dart';
import 'package:shared_design_system/shared_design_system.dart';
import 'package:widgetbook/widgetbook.dart';

import 'ds_story_setup.dart';

part 'ds_caps.stories.g.dart';

const meta = Meta(DsCaps.new);

/// Libellé affiché en capitales ; le texte d'origine reste la donnée et le
/// libellé `Semantics`.
final $Label = _Story(args: _Args(text: StringArg('Taux sans plantage')));

final defaults = _Defaults(
  setup: (context, child, args) =>
      dsStorySetup(Align(alignment: Alignment.topLeft, child: child)),
);
