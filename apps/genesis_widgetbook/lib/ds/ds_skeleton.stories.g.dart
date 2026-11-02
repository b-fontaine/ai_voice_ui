// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'ds_skeleton.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<DsSkeleton, StoryArgs<DsSkeleton>>;
typedef _Scenario = DsSkeletonScenario;
typedef _Defaults = DsSkeletonDefaults;
typedef _Story = DsSkeletonStory;
typedef _Args = DsSkeletonArgs;
final DsSkeletonComponent = Component<DsSkeleton, StoryArgs<DsSkeleton>>(
  name: 'DsSkeleton',
  path: 'ds',
  docComment: r'''État squelette (RG-02) : bloc grisé en attendant les données.

Il ne peint pas le fond du panneau (la décoration du canevas, pdr-0084 U9) :
seul le bloc grisé qui pulse est dessiné, à 16 px du bord de la cellule
(la marge des cellules), avec le rayon `SceneRadius.md`.

Statique par défaut, pour que `pumpAndSettle` termine. Avec
`animate: true`, une pulsation douce tourne sur la période du jeton
`motion.skeleton`, pilotée par `SceneMotionScope.loop` : elle suit la vitesse
de rejeu et s'arrête quand les animations sont coupées.''',
  stories: [$Skeleton..$generatedName = 'Skeleton'],
);
typedef DsSkeletonScenario = Scenario<DsSkeleton, DsSkeletonArgs>;
typedef DsSkeletonDefaults = Defaults<DsSkeleton, DsSkeletonArgs>;

class DsSkeletonStory extends Story<DsSkeleton, DsSkeletonArgs> {
  DsSkeletonStory({
    super.name,
    super.designLink,
    super.setup,
    super.modes,
    DsSkeletonArgs? args,
    StoryWidgetBuilder<DsSkeleton, DsSkeletonArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         args: args ?? DsSkeletonArgs(),
         builder:
             builder ??
             (context, args) =>
                 DsSkeleton(key: args.key, animate: args.animate),
       );
}

class DsSkeletonArgs extends StoryArgs<DsSkeleton> {
  DsSkeletonArgs({Arg<Key?>? key, Arg<bool>? animate})
    : this.keyArg = $initArg('key', key, null),
      this.animateArg = $initArg('animate', animate, BoolArg(false))!;

  DsSkeletonArgs.fixed({Key? key, bool animate = false})
    : this.keyArg = $initArg('key', key == null ? null : Arg.fixed(key), null),
      this.animateArg = $initArg('animate', Arg.fixed(animate), null)!;

  final Arg<Key?>? keyArg;

  final Arg<bool> animateArg;

  Key? get key => keyArg?.value;

  bool get animate => animateArg.value;

  @override
  List<Arg?> get list => [keyArg, animateArg];
}
