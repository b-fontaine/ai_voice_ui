// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'ds_gen_frame.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<DsGenFrame, StoryArgs<DsGenFrame>>;
typedef _Scenario = DsGenFrameScenario;
typedef _Defaults = DsGenFrameDefaults;
typedef _Story = DsGenFrameStory;
typedef _Args = DsGenFrameArgs;
final DsGenFrameComponent = Component<DsGenFrame, StoryArgs<DsGenFrame>>(
  name: 'DsGenFrame',
  path: 'ds',
  docComment: r'''Cadre de génération (`gc-gen`, pdr-0088 F11) : il signale qu'un agent écrit
ce panneau.

Le cadre couvre toute la cellule de son parent et peint dans le rectangle
réduit de [inset] (comme le contour de surbrillance), avec le rayon `lg` :
- une **bordure de 2 px** en arc (`SweepGradient` tournant, transparent puis
  `signal`, `ink`, `signal`) qui fait un tour en 2,8 s (`gc-spin`) ;
- un **balayage** de 40 % de la hauteur, de transparent à `signal` à 25 %,
  qui descend en 2,2 s (`gc-scan`) ;
- une **étiquette** « `Agent` · génère » (« génère » seul sans [agent]) en
  haut à droite, **dans** la cellule (le `top: -11px` de la source déborde).

**Un seul contrôleur** donne les deux phases : sa période est le plus petit
multiple commun des deux durées, dont on tire la rotation et le balayage.
Un seul `RepaintBoundary` (clé `generation-frame-{surfaceId}`) isole la
peinture ; le fondu est un widget d'opacité **au-dessus** de cette clé et
l'étiquette, statique, est hors de la zone repeinte.

Avec [done] (l'agent a fini), le tour en cours s'achève (2,8 s) puis le
cadre s'estompe (0,6 s) ; [onFinished] est alors appelé une fois, après la
dernière image : l'appelant retire le cadre, plus aucune boucle ne reste.

Sous `SceneMotionScope.disabled` (scénario, capture, « réduire les
animations ») : cadre **statique** (arc au repos, pas de balayage) et, dès
[done], retiré **sans fondu** ([onFinished] aussitôt).''',
  stories: [
    $Working..$generatedName = 'Working',
    $NoAgent..$generatedName = 'NoAgent',
  ],
);
typedef DsGenFrameScenario = Scenario<DsGenFrame, DsGenFrameArgs>;
typedef DsGenFrameDefaults = Defaults<DsGenFrame, DsGenFrameArgs>;

class DsGenFrameStory extends Story<DsGenFrame, DsGenFrameArgs> {
  DsGenFrameStory({
    super.name,
    super.designLink,
    SetupBuilder<DsGenFrame, DsGenFrameArgs>? setup,
    super.modes,
    DsGenFrameArgs? args,
    StoryWidgetBuilder<DsGenFrame, DsGenFrameArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         args: args ?? DsGenFrameArgs(),
         builder:
             builder ??
             (context, args) => DsGenFrame(
               key: args.key,
               surfaceId: args.surfaceId,
               agent: args.agent,
               done: args.done,
               onFinished: args.onFinished,
               inset: args.inset,
             ),
         setup: setup ?? defaults.setup!,
       );
}

class DsGenFrameArgs extends StoryArgs<DsGenFrame> {
  DsGenFrameArgs({
    Arg<Key?>? key,
    Arg<String>? surfaceId,
    Arg<String?>? agent,
    Arg<bool>? done,
    Arg<void Function()?>? onFinished,
    Arg<double>? inset,
  }) : this.keyArg = $initArg('key', key, null),
       this.surfaceIdArg = $initArg('surfaceId', surfaceId, StringArg(''))!,
       this.agentArg = $initArg('agent', agent, NullableStringArg(null))!,
       this.doneArg = $initArg('done', done, BoolArg(false))!,
       this.onFinishedArg = $initArg('onFinished', onFinished, null),
       this.insetArg = $initArg('inset', inset, DoubleArg(0))!;

  DsGenFrameArgs.fixed({
    Key? key,
    String surfaceId = '',
    String? agent = null,
    bool done = false,
    void Function()? onFinished,
    double inset = 0,
  }) : this.keyArg = $initArg('key', key == null ? null : Arg.fixed(key), null),
       this.surfaceIdArg = $initArg('surfaceId', Arg.fixed(surfaceId), null)!,
       this.agentArg = $initArg(
         'agent',
         agent == null ? null : Arg.fixed(agent),
         null,
       ),
       this.doneArg = $initArg('done', Arg.fixed(done), null)!,
       this.onFinishedArg = $initArg(
         'onFinished',
         onFinished == null ? null : Arg.fixed(onFinished),
         null,
       ),
       this.insetArg = $initArg('inset', Arg.fixed(inset), null)!;

  final Arg<Key?>? keyArg;

  final Arg<String> surfaceIdArg;

  final Arg<String?>? agentArg;

  final Arg<bool> doneArg;

  final Arg<void Function()?>? onFinishedArg;

  final Arg<double> insetArg;

  Key? get key => keyArg?.value;

  String get surfaceId => surfaceIdArg.value;

  String? get agent => agentArg?.value;

  bool get done => doneArg.value;

  void Function()? get onFinished => onFinishedArg?.value;

  double get inset => insetArg.value;

  @override
  List<Arg?> get list => [
    keyArg,
    surfaceIdArg,
    agentArg,
    doneArg,
    onFinishedArg,
    insetArg,
  ];
}
