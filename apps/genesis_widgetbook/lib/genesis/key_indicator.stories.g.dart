// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'key_indicator.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<KeyIndicator, StoryArgs<KeyIndicator>>;
typedef _Scenario = KeyIndicatorScenario;
typedef _Defaults = KeyIndicatorDefaults;
typedef _Story = KeyIndicatorStory;
typedef _Args = KeyIndicatorArgs;
final KeyIndicatorComponent = Component<KeyIndicator, StoryArgs<KeyIndicator>>(
  name: 'KeyIndicator',
  path: 'genesis',
  docComment: r'''`KeyIndicator` : surface `kpi` (`act1-kpi.jsonl`).''',
  stories: [
    $Data..$generatedName = 'Data',
    $NoData..$generatedName = 'NoData',
    $Neutral..$generatedName = 'Neutral',
  ],
);
typedef KeyIndicatorScenario = Scenario<KeyIndicator, KeyIndicatorArgs>;
typedef KeyIndicatorDefaults = Defaults<KeyIndicator, KeyIndicatorArgs>;

class KeyIndicatorStory extends Story<KeyIndicator, KeyIndicatorArgs> {
  KeyIndicatorStory({
    super.name,
    super.designLink,
    SetupBuilder<KeyIndicator, KeyIndicatorArgs>? setup,
    super.modes,
    KeyIndicatorArgs? args,
    StoryWidgetBuilder<KeyIndicator, KeyIndicatorArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         args: args ?? KeyIndicatorArgs(),
         builder:
             builder ??
             (context, args) => KeyIndicator(key: args.key, state: args.state),
         setup: setup ?? defaults.setup!,
       );
}

class KeyIndicatorArgs extends StoryArgs<KeyIndicator> {
  KeyIndicatorArgs({Arg<Key?>? key, Arg<GenesisSurfaceState>? state})
    : this.keyArg = $initArg('key', key, null),
      this.stateArg = $initArg(
        'state',
        state,
        EnumArg<GenesisSurfaceState>(
          GenesisSurfaceState.data,
          values: GenesisSurfaceState.values,
        ),
      )!;

  KeyIndicatorArgs.fixed({
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
