import 'package:flutter/widgets.dart';
import 'package:shared_design_system/shared_design_system.dart';
import 'package:widgetbook/widgetbook.dart';

import 'ds_story_setup.dart';

part 'ds_gen_frame.stories.g.dart';

const meta = Meta(DsGenFrame.new);

/// Une cellule de la grille 2 x 2 : le cadre couvre la cellule et peint dans
/// le retrait du panneau. L'enveloppe des stories coupe les animations : le
/// cadre est statique (arc au repos, sans balayage), comme en scénario.
final defaults = _Defaults(
  setup: (context, child, args) => dsStorySetup(
    Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 560, height: 240, child: child),
    ),
  ),
);

/// Un agent écrit la surface : « Agent · génère ».
final $Working = _Story(
  args: _Args(
    surfaceId: Arg.fixed('crashes'),
    agent: Arg.fixed('Analyste'),
    done: Arg.fixed(false),
    onFinished: Arg.fixed(null),
    inset: Arg.fixed(ScenePanel.cellInset),
  ),
);

/// Sans agent connu (scénarios, rejeu) : « génère » seul.
final $NoAgent = _Story(
  args: _Args(
    surfaceId: Arg.fixed('crashes'),
    agent: Arg.fixed(null),
    done: Arg.fixed(false),
    onFinished: Arg.fixed(null),
    inset: Arg.fixed(ScenePanel.cellInset),
  ),
);
