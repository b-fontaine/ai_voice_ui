// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'ds_panel_head.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<DsPanelHead, StoryArgs<DsPanelHead>>;
typedef _Scenario = DsPanelHeadScenario;
typedef _Defaults = DsPanelHeadDefaults;
typedef _Story = DsPanelHeadStory;
typedef _Args = DsPanelHeadArgs;
final DsPanelHeadComponent = Component<DsPanelHead, StoryArgs<DsPanelHead>>(
  name: 'DsPanelHead',
  path: 'ds',
  docComment:
      r'''En-tête de panneau (`.gc-panel__head`) : une étiquette ou un titre à
gauche, un statut ou un élément à droite, centrés verticalement.

L'espacement minimal entre les deux côtés est de 12 px et la marge basse de
14 px, comme dans le design system. [DsPanelHead.new] affiche une étiquette
en capitales (style `label`, via [DsCaps]) ; [DsPanelHead.title] affiche un
titre libre dans le style `title`, sans capitales. Le côté gauche se
tronque avant de repousser [trailing], sauf avec [wrap] (retour à la ligne).''',
  stories: [
    $LabelAndStatus..$generatedName = 'LabelAndStatus',
    $LongLabelEllipsis..$generatedName = 'LongLabelEllipsis',
    $TitleWrap..$generatedName = 'TitleWrap',
  ],
);
typedef DsPanelHeadScenario = Scenario<DsPanelHead, DsPanelHeadArgs>;
typedef DsPanelHeadDefaults = Defaults<DsPanelHead, DsPanelHeadArgs>;

class DsPanelHeadStory extends Story<DsPanelHead, DsPanelHeadArgs> {
  DsPanelHeadStory({
    super.name,
    super.designLink,
    SetupBuilder<DsPanelHead, DsPanelHeadArgs>? setup,
    super.modes,
    DsPanelHeadArgs? args,
    StoryWidgetBuilder<DsPanelHead, DsPanelHeadArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         args: args ?? DsPanelHeadArgs(),
         builder:
             builder ??
             (context, args) => DsPanelHead(
               key: args.key,
               label: args.label,
               trailing: args.trailing,
               wrap: args.wrap,
             ),
         setup: setup ?? defaults.setup!,
       );
}

class DsPanelHeadArgs extends StoryArgs<DsPanelHead> {
  DsPanelHeadArgs({
    Arg<Key?>? key,
    Arg<String>? label,
    Arg<Widget?>? trailing,
    Arg<bool>? wrap,
  }) : this.keyArg = $initArg('key', key, null),
       this.labelArg = $initArg('label', label, StringArg(''))!,
       this.trailingArg = $initArg('trailing', trailing, null),
       this.wrapArg = $initArg('wrap', wrap, BoolArg(false))!;

  DsPanelHeadArgs.fixed({
    Key? key,
    String label = '',
    Widget? trailing,
    bool wrap = false,
  }) : this.keyArg = $initArg('key', key == null ? null : Arg.fixed(key), null),
       this.labelArg = $initArg('label', Arg.fixed(label), null)!,
       this.trailingArg = $initArg(
         'trailing',
         trailing == null ? null : Arg.fixed(trailing),
         null,
       ),
       this.wrapArg = $initArg('wrap', Arg.fixed(wrap), null)!;

  final Arg<Key?>? keyArg;

  final Arg<String> labelArg;

  final Arg<Widget?>? trailingArg;

  final Arg<bool> wrapArg;

  Key? get key => keyArg?.value;

  String get label => labelArg.value;

  Widget? get trailing => trailingArg?.value;

  bool get wrap => wrapArg.value;

  @override
  List<Arg?> get list => [keyArg, labelArg, trailingArg, wrapArg];
}
