// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'ds_beacon.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<DsBeacon, StoryArgs<DsBeacon>>;
typedef _Scenario = DsBeaconScenario;
typedef _Defaults = DsBeaconDefaults;
typedef _Story = DsBeaconStory;
typedef _Args = DsBeaconArgs;
final DsBeaconComponent = Component<DsBeacon, StoryArgs<DsBeacon>>(
  name: 'DsBeacon',
  path: 'ds',
  docComment: r'''Point qui bat (`gc-beacon`) : un point plein de [size] px et un halo qui
s'étend de 7 px en s'estompant, période [period] (par défaut
[SceneMotion.beacon]).

Sans [child], le widget dessine lui-même le point plein. Avec [child] (un
point que l'appelant veut garder identifiable, par exemple par une clé), il
ne dessine que le halo, derrière l'enfant.

Isolé dans son `RepaintBoundary` : son battement ne repeint pas la cellule
voisine. **Phase de repos** (animations coupées) : le point seul, sans
halo figé. Un seul contrôleur, lancé une fois par `SceneMotionScope.loop` :
une reconstruction ne le redémarre pas.''',
  stories: [$Dot..$generatedName = 'Dot'],
);
typedef DsBeaconScenario = Scenario<DsBeacon, DsBeaconArgs>;
typedef DsBeaconDefaults = Defaults<DsBeacon, DsBeaconArgs>;

class DsBeaconStory extends Story<DsBeacon, DsBeaconArgs> {
  DsBeaconStory({
    super.name,
    super.designLink,
    SetupBuilder<DsBeacon, DsBeaconArgs>? setup,
    super.modes,
    DsBeaconArgs? args,
    StoryWidgetBuilder<DsBeacon, DsBeaconArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         args: args ?? DsBeaconArgs(),
         builder:
             builder ??
             (context, args) => DsBeacon(
               key: args.key,
               color: args.color,
               size: args.size,
               period: args.period,
               child: args.child,
             ),
         setup: setup ?? defaults.setup!,
       );
}

class DsBeaconArgs extends StoryArgs<DsBeacon> {
  DsBeaconArgs({
    Arg<Key?>? key,
    Arg<Color>? color,
    Arg<double>? size,
    Arg<Duration>? period,
    Arg<Widget?>? child,
  }) : this.keyArg = $initArg('key', key, null),
       this.colorArg = $initArg(
         'color',
         color,
         ColorArg(const Color(4278190080)),
       )!,
       this.sizeArg = $initArg('size', size, DoubleArg(0.0))!,
       this.periodArg = $initArg(
         'period',
         period,
         DurationArg(SceneMotion.beacon),
       )!,
       this.childArg = $initArg('child', child, null);

  DsBeaconArgs.fixed({
    Key? key,
    Color color = const Color(4278190080),
    double size = 0.0,
    Duration period = SceneMotion.beacon,
    Widget? child,
  }) : this.keyArg = $initArg('key', key == null ? null : Arg.fixed(key), null),
       this.colorArg = $initArg('color', Arg.fixed(color), null)!,
       this.sizeArg = $initArg('size', Arg.fixed(size), null)!,
       this.periodArg = $initArg('period', Arg.fixed(period), null)!,
       this.childArg = $initArg(
         'child',
         child == null ? null : Arg.fixed(child),
         null,
       );

  final Arg<Key?>? keyArg;

  final Arg<Color> colorArg;

  final Arg<double> sizeArg;

  final Arg<Duration> periodArg;

  final Arg<Widget?>? childArg;

  Key? get key => keyArg?.value;

  Color get color => colorArg.value;

  double get size => sizeArg.value;

  Duration get period => periodArg.value;

  Widget? get child => childArg?.value;

  @override
  List<Arg?> get list => [keyArg, colorArg, sizeArg, periodArg, childArg];
}
