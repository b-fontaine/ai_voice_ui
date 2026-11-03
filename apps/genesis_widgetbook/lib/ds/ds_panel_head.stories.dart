import 'package:flutter/widgets.dart';
import 'package:shared_design_system/shared_design_system.dart';
import 'package:widgetbook/widgetbook.dart';

import 'ds_story_setup.dart';

part 'ds_panel_head.stories.g.dart';

const meta = Meta(DsPanelHead.new);

/// Étiquette en capitales à gauche, puce de statut à droite.
final $LabelAndStatus = _Story(
  args: _Args(
    label: StringArg('Qualité des crashs'),
    trailing: Arg.fixed(
      const DsStatusChip(status: SceneStatus.ok, label: 'Prêt'),
    ),
    wrap: BoolArg(false),
  ),
);

/// Étiquette trop longue pour la cellule : elle se tronque (ellipse) avant de
/// repousser le statut.
final $LongLabelEllipsis = _Story(
  args: _Args(
    label: StringArg(
      'Taux de sessions sans plantage sur les sept derniers jours glissants '
      'de la version candidate, tous appareils confondus',
    ),
    trailing: Arg.fixed(
      const DsStatusChip(status: SceneStatus.blocking, label: 'Bloquant'),
    ),
    wrap: BoolArg(false),
  ),
);

/// Titre libre (`DsPanelHead.title`, sans capitales) qui passe à la ligne
/// (`wrap`) au lieu de se tronquer. Le `setup` remplace l'en-tête par cette
/// variante : le `builder` généré doit rendre un `DsPanelHead`.
final $TitleWrap = _Story(
  args: _Args(
    label: StringArg('Titre'),
    trailing: Arg.fixed(null),
    wrap: BoolArg(true),
  ),
  setup: (context, child, args) => dsStorySetup(
    const DsPanelHead.title(
      title:
          'Une description de version assez longue pour passer à la ligne '
          'dans la cellule du catalogue',
      wrap: true,
    ),
  ),
);

/// L'en-tête occupe la largeur de la cellule (le `Row` est étiré).
final defaults = _Defaults(
  setup: (context, child, args) =>
      dsStorySetup(Align(alignment: Alignment.topLeft, child: child)),
);
