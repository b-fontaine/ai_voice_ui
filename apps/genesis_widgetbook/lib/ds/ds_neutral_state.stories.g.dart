// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'ds_neutral_state.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<DsNeutralState, StoryArgs<DsNeutralState>>;
typedef _Scenario = DsNeutralStateScenario;
typedef _Defaults = DsNeutralStateDefaults;
typedef _Story = DsNeutralStateStory;
typedef _Args = DsNeutralStateArgs;
final DsNeutralStateComponent =
    Component<DsNeutralState, StoryArgs<DsNeutralState>>(
      name: 'DsNeutralState',
      path: 'ds',
      docComment:
          r'''État neutre (RG-10) : message court, jamais d'erreur affichée.''',
      stories: [$Neutral..$generatedName = 'Neutral'],
    );
typedef DsNeutralStateScenario = Scenario<DsNeutralState, DsNeutralStateArgs>;
typedef DsNeutralStateDefaults = Defaults<DsNeutralState, DsNeutralStateArgs>;

class DsNeutralStateStory extends Story<DsNeutralState, DsNeutralStateArgs> {
  DsNeutralStateStory({
    super.name,
    super.designLink,
    SetupBuilder<DsNeutralState, DsNeutralStateArgs>? setup,
    super.modes,
    DsNeutralStateArgs? args,
    StoryWidgetBuilder<DsNeutralState, DsNeutralStateArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         args: args ?? DsNeutralStateArgs(),
         builder:
             builder ??
             (context, args) =>
                 DsNeutralState(key: args.key, message: args.message),
         setup: setup ?? defaults.setup!,
       );
}

class DsNeutralStateArgs extends StoryArgs<DsNeutralState> {
  DsNeutralStateArgs({Arg<Key?>? key, Arg<String>? message})
    : this.keyArg = $initArg('key', key, null),
      this.messageArg = $initArg(
        'message',
        message,
        StringArg('Données indisponibles'),
      )!;

  DsNeutralStateArgs.fixed({Key? key, String message = 'Données indisponibles'})
    : this.keyArg = $initArg('key', key == null ? null : Arg.fixed(key), null),
      this.messageArg = $initArg('message', Arg.fixed(message), null)!;

  final Arg<Key?>? keyArg;

  final Arg<String> messageArg;

  Key? get key => keyArg?.value;

  String get message => messageArg.value;

  @override
  List<Arg?> get list => [keyArg, messageArg];
}
