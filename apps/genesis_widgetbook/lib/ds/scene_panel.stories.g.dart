// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'scene_panel.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<ScenePanel, StoryArgs<ScenePanel>>;
typedef _Scenario = ScenePanelScenario;
typedef _Defaults = ScenePanelDefaults;
typedef _Story = ScenePanelStory;
typedef _Args = ScenePanelArgs;
final ScenePanelComponent = Component<ScenePanel, StoryArgs<ScenePanel>>(
  name: 'ScenePanel',
  path: 'ds',
  docComment: r'''Panneau pratique : [ScenePanelDecoration] en dessous, [child] au-dessus.

La décoration est une couche sœur du contenu, jamais son enveloppe : elle
est retirée de [inset] sur chaque bord (les cellules d'une grille sont
jointives ; 4 px de retrait laissent 8 px visibles entre deux panneaux), et
le [child] est placé à [padding] du bord de la cellule. L'enfant mesure
donc largeur − padding.horizontal et hauteur − padding.vertical ; la
décoration, largeur − 2 × inset.''',
  stories: [
    $Default..$generatedName = 'Default',
    $CustomPadding..$generatedName = 'CustomPadding',
    $Glow..$generatedName = 'Glow',
  ],
);
typedef ScenePanelScenario = Scenario<ScenePanel, ScenePanelArgs>;
typedef ScenePanelDefaults = Defaults<ScenePanel, ScenePanelArgs>;

class ScenePanelStory extends Story<ScenePanel, ScenePanelArgs> {
  ScenePanelStory({
    super.name,
    super.designLink,
    super.setup,
    super.modes,
    required super.args,
    StoryWidgetBuilder<ScenePanel, ScenePanelArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         builder:
             builder ??
             (context, args) => ScenePanel(
               key: args.key,
               child: args.child,
               padding: args.padding,
               inset: args.inset,
               glow: args.glow,
             ),
       );
}

class ScenePanelArgs extends StoryArgs<ScenePanel> {
  ScenePanelArgs({
    Arg<Key?>? key,
    required Arg<Widget> child,
    Arg<EdgeInsetsGeometry>? padding,
    Arg<double>? inset,
    Arg<List<BoxShadow>?>? glow,
  }) : this.keyArg = $initArg('key', key, null),
       this.childArg = $initArg('child', child, null)!,
       this.paddingArg = $initArg(
         'padding',
         padding,
         ConstArg(const EdgeInsets.all(SceneSpace.space4)),
       )!,
       this.insetArg = $initArg(
         'inset',
         inset,
         DoubleArg(ScenePanel.cellInset),
       )!,
       this.glowArg = $initArg('glow', glow, null);

  ScenePanelArgs.fixed({
    Key? key,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(SceneSpace.space4),
    double inset = ScenePanel.cellInset,
    List<BoxShadow>? glow,
  }) : this.keyArg = $initArg('key', key == null ? null : Arg.fixed(key), null),
       this.childArg = $initArg('child', Arg.fixed(child), null)!,
       this.paddingArg = $initArg('padding', Arg.fixed(padding), null)!,
       this.insetArg = $initArg('inset', Arg.fixed(inset), null)!,
       this.glowArg = $initArg(
         'glow',
         glow == null ? null : Arg.fixed(glow),
         null,
       );

  final Arg<Key?>? keyArg;

  final Arg<Widget> childArg;

  final Arg<EdgeInsetsGeometry> paddingArg;

  final Arg<double> insetArg;

  final Arg<List<BoxShadow>?>? glowArg;

  Key? get key => keyArg?.value;

  Widget get child => childArg.value;

  EdgeInsetsGeometry get padding => paddingArg.value;

  double get inset => insetArg.value;

  List<BoxShadow>? get glow => glowArg?.value;

  @override
  List<Arg?> get list => [keyArg, childArg, paddingArg, insetArg, glowArg];
}
