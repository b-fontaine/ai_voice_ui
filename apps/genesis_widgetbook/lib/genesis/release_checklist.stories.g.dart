// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'release_checklist.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<ReleaseChecklist, StoryArgs<ReleaseChecklist>>;
typedef _Scenario = ReleaseChecklistScenario;
typedef _Defaults = ReleaseChecklistDefaults;
typedef _Story = ReleaseChecklistStory;
typedef _Args = ReleaseChecklistArgs;
final ReleaseChecklistComponent =
    Component<ReleaseChecklist, StoryArgs<ReleaseChecklist>>(
      name: 'ReleaseChecklist',
      path: 'genesis',
      docComment: r'''`ReleaseChecklist` : surface `checklist` (`act1-checklist.jsonl`).''',
      stories: [
        $Data..$generatedName = 'Data',
        $NoData..$generatedName = 'NoData',
        $Neutral..$generatedName = 'Neutral',
      ],
    );
typedef ReleaseChecklistScenario =
    Scenario<ReleaseChecklist, ReleaseChecklistArgs>;
typedef ReleaseChecklistDefaults =
    Defaults<ReleaseChecklist, ReleaseChecklistArgs>;

class ReleaseChecklistStory
    extends Story<ReleaseChecklist, ReleaseChecklistArgs> {
  ReleaseChecklistStory({
    super.name,
    super.designLink,
    SetupBuilder<ReleaseChecklist, ReleaseChecklistArgs>? setup,
    super.modes,
    ReleaseChecklistArgs? args,
    StoryWidgetBuilder<ReleaseChecklist, ReleaseChecklistArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         args: args ?? ReleaseChecklistArgs(),
         builder:
             builder ??
             (context, args) =>
                 ReleaseChecklist(key: args.key, state: args.state),
         setup: setup ?? defaults.setup!,
       );
}

class ReleaseChecklistArgs extends StoryArgs<ReleaseChecklist> {
  ReleaseChecklistArgs({Arg<Key?>? key, Arg<GenesisSurfaceState>? state})
    : this.keyArg = $initArg('key', key, null),
      this.stateArg = $initArg(
        'state',
        state,
        EnumArg<GenesisSurfaceState>(
          GenesisSurfaceState.data,
          values: GenesisSurfaceState.values,
        ),
      )!;

  ReleaseChecklistArgs.fixed({
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
