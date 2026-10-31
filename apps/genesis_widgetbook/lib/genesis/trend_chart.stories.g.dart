// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'trend_chart.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<TrendChart, StoryArgs<TrendChart>>;
typedef _Scenario = TrendChartScenario;
typedef _Defaults = TrendChartDefaults;
typedef _Story = TrendChartStory;
typedef _Args = TrendChartArgs;
final TrendChartComponent = Component<TrendChart, StoryArgs<TrendChart>>(
  name: 'TrendChart',
  path: 'genesis',
  docComment: r'''`TrendChart` : surface `trend` (`act1-trend.jsonl`).''',
  stories: [
    $Data..$generatedName = 'Data',
    $NoData..$generatedName = 'NoData',
    $Neutral..$generatedName = 'Neutral',
  ],
);
typedef TrendChartScenario = Scenario<TrendChart, TrendChartArgs>;
typedef TrendChartDefaults = Defaults<TrendChart, TrendChartArgs>;

class TrendChartStory extends Story<TrendChart, TrendChartArgs> {
  TrendChartStory({
    super.name,
    super.designLink,
    SetupBuilder<TrendChart, TrendChartArgs>? setup,
    super.modes,
    TrendChartArgs? args,
    StoryWidgetBuilder<TrendChart, TrendChartArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         args: args ?? TrendChartArgs(),
         builder:
             builder ??
             (context, args) => TrendChart(key: args.key, state: args.state),
         setup: setup ?? defaults.setup!,
       );
}

class TrendChartArgs extends StoryArgs<TrendChart> {
  TrendChartArgs({Arg<Key?>? key, Arg<GenesisSurfaceState>? state})
    : this.keyArg = $initArg('key', key, null),
      this.stateArg = $initArg(
        'state',
        state,
        EnumArg<GenesisSurfaceState>(
          GenesisSurfaceState.data,
          values: GenesisSurfaceState.values,
        ),
      )!;

  TrendChartArgs.fixed({
    Key? key,
    GenesisSurfaceState state = GenesisSurfaceState.data,
  }) : this.keyArg = $initArg('key', key == null ? null : Arg.fixed(key), null),
       this.stateArg = $initArg('state', Arg.fixed(state), null)!;

  final Arg<Key?>? keyArg;

  final Arg<GenesisSurfaceState> stateArg;

  Key? get key => keyArg?.value;

  GenesisSurfaceState get state => stateArg.value;

  @override
  List<Arg?> get list => [keyArg, stateArg];
}
