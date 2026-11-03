// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'ds_blink.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<DsBlink, StoryArgs<DsBlink>>;
typedef _Scenario = DsBlinkScenario;
typedef _Defaults = DsBlinkDefaults;
typedef _Story = DsBlinkStory;
typedef _Args = DsBlinkArgs;
final DsBlinkComponent = Component<DsBlink, StoryArgs<DsBlink>>(
  name: 'DsBlink',
  path: 'ds',
  docComment: r'''Clignotement en créneaux (`gc-blink`, `steps(2)`, pdr-0088 F9) : l'enfant
est plein pendant la première moitié de la [period], à [dimmedOpacity]
pendant la seconde.

La période est mise à l'échelle par `SceneMotionScope.loop` (une seule
source de vérité : vitesse de rejeu et `disabled`). Un seul contrôleur par
instance, lancé une fois : une reconstruction du parent ne le redémarre
pas. **Phase de repos** (animations coupées) : l'enfant reste **plein**
(phase 0), jamais figé à demi-teinte.

Chaque instance a son `RepaintBoundary` : le clignotement ne repeint pas
ses voisins (curseur, point d'enregistrement, losange de l'étiquette). Le
clignotement est un `FadeTransition` : l'opacité suit le contrôleur au
niveau du rendu, sans reconstruction. Un `AnimatedBuilder` ferait
reconstruire, à chaque image, un `LayoutBuilder` ancêtre (donc sa mise en
page et la peinture du parent).''',
  stories: [$Solid..$generatedName = 'Solid'],
);
typedef DsBlinkScenario = Scenario<DsBlink, DsBlinkArgs>;
typedef DsBlinkDefaults = Defaults<DsBlink, DsBlinkArgs>;

class DsBlinkStory extends Story<DsBlink, DsBlinkArgs> {
  DsBlinkStory({
    super.name,
    super.designLink,
    SetupBuilder<DsBlink, DsBlinkArgs>? setup,
    super.modes,
    required super.args,
    StoryWidgetBuilder<DsBlink, DsBlinkArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         builder:
             builder ??
             (context, args) =>
                 DsBlink(key: args.key, child: args.child, period: args.period),
         setup: setup ?? defaults.setup!,
       );
}

class DsBlinkArgs extends StoryArgs<DsBlink> {
  DsBlinkArgs({
    Arg<Key?>? key,
    required Arg<Widget> child,
    Arg<Duration>? period,
  }) : this.keyArg = $initArg('key', key, null),
       this.childArg = $initArg('child', child, null)!,
       this.periodArg = $initArg(
         'period',
         period,
         DurationArg(SceneMotion.blink),
       )!;

  DsBlinkArgs.fixed({
    Key? key,
    required Widget child,
    Duration period = SceneMotion.blink,
  }) : this.keyArg = $initArg('key', key == null ? null : Arg.fixed(key), null),
       this.childArg = $initArg('child', Arg.fixed(child), null)!,
       this.periodArg = $initArg('period', Arg.fixed(period), null)!;

  final Arg<Key?>? keyArg;

  final Arg<Widget> childArg;

  final Arg<Duration> periodArg;

  Key? get key => keyArg?.value;

  Widget get child => childArg.value;

  Duration get period => periodArg.value;

  @override
  List<Arg?> get list => [keyArg, childArg, periodArg];
}
