// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'ds_caps.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<DsCaps, StoryArgs<DsCaps>>;
typedef _Scenario = DsCapsScenario;
typedef _Defaults = DsCapsDefaults;
typedef _Story = DsCapsStory;
typedef _Args = DsCapsArgs;
final DsCapsComponent = Component<DsCaps, StoryArgs<DsCaps>>(
  name: 'DsCaps',
  path: 'ds',
  docComment: r'''Texte affiché en capitales (`text-transform: uppercase` du design system),
sans que la donnée ni la sémantique changent.

Le texte est mis en capitales **à l'affichage seulement** (`toUpperCase`) :
la chaîne d'origine reste la donnée (backend, clés, tests de contenu) et
devient le libellé `Semantics` ; le texte affiché est exclu de la
sémantique pour que le lecteur d'écran n'annonce pas deux fois le mot.

Usage : étiquettes `label`, puces de statut, en-têtes de tableau, segments
d'actes. Jamais les chaînes de données (valeurs, noms de critères,
verbatims, transcription). Un test qui cherche un tel libellé utilise
`findTextIgnoringCase` (`testing_real_fonts`) ou la sémantique, jamais
`find.text` avec la casse d'origine.''',
  stories: [$Label..$generatedName = 'Label'],
);
typedef DsCapsScenario = Scenario<DsCaps, DsCapsArgs>;
typedef DsCapsDefaults = Defaults<DsCaps, DsCapsArgs>;

class DsCapsStory extends Story<DsCaps, DsCapsArgs> {
  DsCapsStory({
    super.name,
    super.designLink,
    SetupBuilder<DsCaps, DsCapsArgs>? setup,
    super.modes,
    DsCapsArgs? args,
    StoryWidgetBuilder<DsCaps, DsCapsArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         args: args ?? DsCapsArgs(),
         builder:
             builder ??
             (context, args) => DsCaps(
               args.text,
               key: args.key,
               style: args.style,
               maxLines: args.maxLines,
               overflow: args.overflow,
               textAlign: args.textAlign,
             ),
         setup: setup ?? defaults.setup!,
       );
}

class DsCapsArgs extends StoryArgs<DsCaps> {
  DsCapsArgs({
    Arg<String>? text,
    Arg<Key?>? key,
    Arg<TextStyle?>? style,
    Arg<int?>? maxLines,
    Arg<TextOverflow?>? overflow,
    Arg<TextAlign?>? textAlign,
  }) : this.textArg = $initArg('text', text, StringArg(''))!,
       this.keyArg = $initArg('key', key, null),
       this.styleArg = $initArg('style', style, null),
       this.maxLinesArg = $initArg('maxLines', maxLines, NullableIntArg(null))!,
       this.overflowArg = $initArg(
         'overflow',
         overflow,
         NullableEnumArg<TextOverflow>(null, values: TextOverflow.values),
       )!,
       this.textAlignArg = $initArg(
         'textAlign',
         textAlign,
         NullableEnumArg<TextAlign>(null, values: TextAlign.values),
       )!;

  DsCapsArgs.fixed({
    String text = '',
    Key? key,
    TextStyle? style,
    int? maxLines = null,
    TextOverflow? overflow = null,
    TextAlign? textAlign = null,
  }) : this.textArg = $initArg('text', Arg.fixed(text), null)!,
       this.keyArg = $initArg('key', key == null ? null : Arg.fixed(key), null),
       this.styleArg = $initArg(
         'style',
         style == null ? null : Arg.fixed(style),
         null,
       ),
       this.maxLinesArg = $initArg(
         'maxLines',
         maxLines == null ? null : Arg.fixed(maxLines),
         null,
       ),
       this.overflowArg = $initArg(
         'overflow',
         overflow == null ? null : Arg.fixed(overflow),
         null,
       ),
       this.textAlignArg = $initArg(
         'textAlign',
         textAlign == null ? null : Arg.fixed(textAlign),
         null,
       );

  final Arg<String> textArg;

  final Arg<Key?>? keyArg;

  final Arg<TextStyle?>? styleArg;

  final Arg<int?>? maxLinesArg;

  final Arg<TextOverflow?>? overflowArg;

  final Arg<TextAlign?>? textAlignArg;

  String get text => textArg.value;

  Key? get key => keyArg?.value;

  TextStyle? get style => styleArg?.value;

  int? get maxLines => maxLinesArg?.value;

  TextOverflow? get overflow => overflowArg?.value;

  TextAlign? get textAlign => textAlignArg?.value;

  @override
  List<Arg?> get list => [
    textArg,
    keyArg,
    styleArg,
    maxLinesArg,
    overflowArg,
    textAlignArg,
  ];
}
