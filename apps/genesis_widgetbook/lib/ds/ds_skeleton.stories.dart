import 'package:flutter/widgets.dart';
import 'package:shared_design_system/shared_design_system.dart';
import 'package:widgetbook/widgetbook.dart';

import 'ds_story_setup.dart';

part 'ds_skeleton.stories.g.dart';

const meta = Meta(DsSkeleton.new);

/// Le squelette remplit l'espace disponible : on lui donne une taille de
/// cellule pour qu'il reste visible hors viewport.
final $Skeleton = _Story(
  setup: (context, child, args) => dsStorySetup(
    Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 320, height: 160, child: child),
    ),
  ),
  args: _Args(animate: Arg.fixed(false)),
);
