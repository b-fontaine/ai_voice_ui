// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'ds_status_chip.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<DsStatusChip, StoryArgs<DsStatusChip>>;
typedef _Scenario = DsStatusChipScenario;
typedef _Defaults = DsStatusChipDefaults;
typedef _Story = DsStatusChipStory;
typedef _Args = DsStatusChipArgs;
final DsStatusChipComponent = Component<DsStatusChip, StoryArgs<DsStatusChip>>(
  name: 'DsStatusChip',
  path: 'ds',
  docComment:
      r'''Pastille de statut : la couleur vient du [SceneStatus], le libellé
(fourni par le backend) est affiché tel quel. Statut `null` : style neutre.''',
  stories: [
    $Ok..$generatedName = 'Ok',
    $Risk..$generatedName = 'Risk',
    $Blocking..$generatedName = 'Blocking',
    $Neutral..$generatedName = 'Neutral',
  ],
);
typedef DsStatusChipScenario = Scenario<DsStatusChip, DsStatusChipArgs>;
typedef DsStatusChipDefaults = Defaults<DsStatusChip, DsStatusChipArgs>;

class DsStatusChipStory extends Story<DsStatusChip, DsStatusChipArgs> {
  DsStatusChipStory({
    super.name,
    super.designLink,
    SetupBuilder<DsStatusChip, DsStatusChipArgs>? setup,
    super.modes,
    DsStatusChipArgs? args,
    StoryWidgetBuilder<DsStatusChip, DsStatusChipArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         args: args ?? DsStatusChipArgs(),
         builder:
             builder ??
             (context, args) => DsStatusChip(
               key: args.key,
               status: args.status,
               label: args.label,
             ),
         setup: setup ?? defaults.setup!,
       );
}

class DsStatusChipArgs extends StoryArgs<DsStatusChip> {
  DsStatusChipArgs({
    Arg<Key?>? key,
    Arg<SceneStatus?>? status,
    Arg<String>? label,
  }) : this.keyArg = $initArg('key', key, null),
       this.statusArg = $initArg(
         'status',
         status,
         NullableEnumArg<SceneStatus>(null, values: SceneStatus.values),
       )!,
       this.labelArg = $initArg('label', label, StringArg(''))!;

  DsStatusChipArgs.fixed({
    Key? key,
    SceneStatus? status = null,
    String label = '',
  }) : this.keyArg = $initArg('key', key == null ? null : Arg.fixed(key), null),
       this.statusArg = $initArg(
         'status',
         status == null ? null : Arg.fixed(status),
         null,
       ),
       this.labelArg = $initArg('label', Arg.fixed(label), null)!;

  final Arg<Key?>? keyArg;

  final Arg<SceneStatus?>? statusArg;

  final Arg<String> labelArg;

  Key? get key => keyArg?.value;

  SceneStatus? get status => statusArg?.value;

  String get label => labelArg.value;

  @override
  List<Arg?> get list => [keyArg, statusArg, labelArg];
}
