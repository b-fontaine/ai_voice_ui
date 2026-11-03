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
(fourni par le backend) est affiché tel quel dans la donnée, en capitales
à l'affichage (`DsCaps`, le `Semantics` garde la casse d'origine). Statut
`null` : style neutre (`gc-badge--idle`).

Selon le design system (`gc-badge`, pdr-0088 F1, pdr-0084 U6) :
- pilule de [height] (26) px, grande puce [large] de [largeHeight] (40) px
  pour le verdict, avec la lueur `glow-nogo` si le statut est bloquant ;
- bordure de 1 px à la couleur du mot (`currentColor`) ; statut inconnu :
  bordure `line-strong` ;
- `ok` porte un glyphe ✓ de la couleur `go`, séparé du mot ;
- `blocking` porte un point de [dotSize] px `nogo` qui bat (`gc-beacon`,
  seule animation en boucle des statuts) ;
- `risk` et le statut inconnu n'ont ni glyphe ni point.

Le glyphe et le point sont décoratifs : ils sont exclus de la sémantique,
seul le mot est annoncé.''',
  stories: [
    $Ok..$generatedName = 'Ok',
    $Risk..$generatedName = 'Risk',
    $Blocking..$generatedName = 'Blocking',
    $Verdict..$generatedName = 'Verdict',
    $Neutral..$generatedName = 'Neutral',
    $AllStatuses..$generatedName = 'AllStatuses',
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
               large: args.large,
             ),
         setup: setup ?? defaults.setup!,
       );
}

class DsStatusChipArgs extends StoryArgs<DsStatusChip> {
  DsStatusChipArgs({
    Arg<Key?>? key,
    Arg<SceneStatus?>? status,
    Arg<String>? label,
    Arg<bool>? large,
  }) : this.keyArg = $initArg('key', key, null),
       this.statusArg = $initArg(
         'status',
         status,
         NullableEnumArg<SceneStatus>(null, values: SceneStatus.values),
       )!,
       this.labelArg = $initArg('label', label, StringArg(''))!,
       this.largeArg = $initArg('large', large, BoolArg(false))!;

  DsStatusChipArgs.fixed({
    Key? key,
    SceneStatus? status = null,
    String label = '',
    bool large = false,
  }) : this.keyArg = $initArg('key', key == null ? null : Arg.fixed(key), null),
       this.statusArg = $initArg(
         'status',
         status == null ? null : Arg.fixed(status),
         null,
       ),
       this.labelArg = $initArg('label', Arg.fixed(label), null)!,
       this.largeArg = $initArg('large', Arg.fixed(large), null)!;

  final Arg<Key?>? keyArg;

  final Arg<SceneStatus?>? statusArg;

  final Arg<String> labelArg;

  final Arg<bool> largeArg;

  Key? get key => keyArg?.value;

  SceneStatus? get status => statusArg?.value;

  String get label => labelArg.value;

  bool get large => largeArg.value;

  @override
  List<Arg?> get list => [keyArg, statusArg, labelArg, largeArg];
}
