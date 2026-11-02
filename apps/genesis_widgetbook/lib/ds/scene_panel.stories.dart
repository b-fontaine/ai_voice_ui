import 'package:flutter/widgets.dart';
import 'package:shared_design_system/shared_design_system.dart';
import 'package:widgetbook/widgetbook.dart';

part 'scene_panel.stories.g.dart';

const meta = Meta(ScenePanel.new);

Widget _content() => const Text('Contenu du panneau');

/// Marge intérieure par défaut (16 px).
final $Default = _Story(args: _Args(child: Arg.fixed(_content())));

/// Marge intérieure personnalisée.
final $CustomPadding = _Story(
  args: _Args(
    child: Arg.fixed(_content()),
    padding: Arg.fixed(const EdgeInsets.fromLTRB(32, 24, 8, 8)),
  ),
);

/// Zone active : halo de signal autour du panneau.
final $Glow = _Story(
  args: _Args(
    child: Arg.fixed(_content()),
    glow: Arg.fixed(SceneShadow.glowSignal),
  ),
);
