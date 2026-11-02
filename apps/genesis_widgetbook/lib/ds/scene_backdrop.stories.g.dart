// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'scene_backdrop.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<SceneBackdrop, StoryArgs<SceneBackdrop>>;
typedef _Scenario = SceneBackdropScenario;
typedef _Defaults = SceneBackdropDefaults;
typedef _Story = SceneBackdropStory;
typedef _Args = SceneBackdropArgs;
final SceneBackdropComponent =
    Component<SceneBackdrop, StoryArgs<SceneBackdrop>>(
      name: 'SceneBackdrop',
      path: 'ds',
      docComment: r'''Fond d'écran du design system (pdr-0084 U9) : `SceneTheme.background`
(void) et grille de points `line` au pas de `SceneSpace.space6` (24 px),
un point au centre de chaque tuile.

La grille est peinte en un seul `drawPoints`, dans son `RepaintBoundary` :
elle ne se repeint que si la taille ou la couleur change, jamais quand le
contenu [child] (au-dessus) bouge.''',
      stories: [$FullFrame..$generatedName = 'FullFrame'],
    );
typedef SceneBackdropScenario = Scenario<SceneBackdrop, SceneBackdropArgs>;
typedef SceneBackdropDefaults = Defaults<SceneBackdrop, SceneBackdropArgs>;

class SceneBackdropStory extends Story<SceneBackdrop, SceneBackdropArgs> {
  SceneBackdropStory({
    super.name,
    super.designLink,
    super.setup,
    super.modes,
    SceneBackdropArgs? args,
    StoryWidgetBuilder<SceneBackdrop, SceneBackdropArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         args: args ?? SceneBackdropArgs(),
         builder:
             builder ??
             (context, args) => SceneBackdrop(key: args.key, child: args.child),
       );
}

class SceneBackdropArgs extends StoryArgs<SceneBackdrop> {
  SceneBackdropArgs({Arg<Key?>? key, Arg<Widget?>? child})
    : this.keyArg = $initArg('key', key, null),
      this.childArg = $initArg('child', child, null);

  SceneBackdropArgs.fixed({Key? key, Widget? child})
    : this.keyArg = $initArg('key', key == null ? null : Arg.fixed(key), null),
      this.childArg = $initArg(
        'child',
        child == null ? null : Arg.fixed(child),
        null,
      );

  final Arg<Key?>? keyArg;

  final Arg<Widget?>? childArg;

  Key? get key => keyArg?.value;

  Widget? get child => childArg?.value;

  @override
  List<Arg?> get list => [keyArg, childArg];
}
