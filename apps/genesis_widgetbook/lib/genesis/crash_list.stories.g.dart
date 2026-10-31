// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'crash_list.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<CrashList, StoryArgs<CrashList>>;
typedef _Scenario = CrashListScenario;
typedef _Defaults = CrashListDefaults;
typedef _Story = CrashListStory;
typedef _Args = CrashListArgs;
final CrashListComponent = Component<CrashList, StoryArgs<CrashList>>(
  name: 'CrashList',
  path: 'genesis',
  docComment:
      r'''`CrashList` : surface `crashes` (`crashlist-global.jsonl`).''',
  stories: [
    $Data..$generatedName = 'Data',
    $NoData..$generatedName = 'NoData',
    $Neutral..$generatedName = 'Neutral',
  ],
);
typedef CrashListScenario = Scenario<CrashList, CrashListArgs>;
typedef CrashListDefaults = Defaults<CrashList, CrashListArgs>;

class CrashListStory extends Story<CrashList, CrashListArgs> {
  CrashListStory({
    super.name,
    super.designLink,
    SetupBuilder<CrashList, CrashListArgs>? setup,
    super.modes,
    CrashListArgs? args,
    StoryWidgetBuilder<CrashList, CrashListArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         args: args ?? CrashListArgs(),
         builder:
             builder ??
             (context, args) => CrashList(key: args.key, state: args.state),
         setup: setup ?? defaults.setup!,
       );
}

class CrashListArgs extends StoryArgs<CrashList> {
  CrashListArgs({Arg<Key?>? key, Arg<GenesisSurfaceState>? state})
    : this.keyArg = $initArg('key', key, null),
      this.stateArg = $initArg(
        'state',
        state,
        EnumArg<GenesisSurfaceState>(
          GenesisSurfaceState.data,
          values: GenesisSurfaceState.values,
        ),
      )!;

  CrashListArgs.fixed({
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
