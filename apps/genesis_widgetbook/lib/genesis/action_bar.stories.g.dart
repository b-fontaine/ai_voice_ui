// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'action_bar.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<ActionBar, StoryArgs<ActionBar>>;
typedef _Scenario = ActionBarScenario;
typedef _Defaults = ActionBarDefaults;
typedef _Story = ActionBarStory;
typedef _Args = ActionBarArgs;
final ActionBarComponent = Component<ActionBar, StoryArgs<ActionBar>>(
  name: 'ActionBar',
  path: 'genesis',
  docComment: r'''`ActionBar` : surface `actions` (`act2-actions.jsonl`).''',
  stories: [
    $Data..$generatedName = 'Data',
    $NoData..$generatedName = 'NoData',
    $Neutral..$generatedName = 'Neutral',
  ],
);
typedef ActionBarScenario = Scenario<ActionBar, ActionBarArgs>;
typedef ActionBarDefaults = Defaults<ActionBar, ActionBarArgs>;

class ActionBarStory extends Story<ActionBar, ActionBarArgs> {
  ActionBarStory({
    super.name,
    super.designLink,
    SetupBuilder<ActionBar, ActionBarArgs>? setup,
    super.modes,
    ActionBarArgs? args,
    StoryWidgetBuilder<ActionBar, ActionBarArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         args: args ?? ActionBarArgs(),
         builder:
             builder ??
             (context, args) => ActionBar(key: args.key, state: args.state),
         setup: setup ?? defaults.setup!,
       );
}

class ActionBarArgs extends StoryArgs<ActionBar> {
  ActionBarArgs({Arg<Key?>? key, Arg<GenesisSurfaceState>? state})
    : this.keyArg = $initArg('key', key, null),
      this.stateArg = $initArg(
        'state',
        state,
        EnumArg<GenesisSurfaceState>(
          GenesisSurfaceState.data,
          values: GenesisSurfaceState.values,
        ),
      )!;

  ActionBarArgs.fixed({
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
