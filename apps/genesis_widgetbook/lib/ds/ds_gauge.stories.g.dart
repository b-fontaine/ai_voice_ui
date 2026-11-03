// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'ds_gauge.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<DsGauge, StoryArgs<DsGauge>>;
typedef _Scenario = DsGaugeScenario;
typedef _Defaults = DsGaugeDefaults;
typedef _Story = DsGaugeStory;
typedef _Args = DsGaugeArgs;
final DsGaugeComponent = Component<DsGauge, StoryArgs<DsGauge>>(
  name: 'DsGauge',
  path: 'ds',
  docComment: r'''Jauge d'un indicateur clé (`.gc-gauge`, pdr-0088 F3) : piste de [trackHeight]
px en `surface-300` (rayon 4), remplissage de la couleur donnée, marque de
seuil et repère de comparaison.

Toutes les positions sont des **fractions** (0 à 1) de la largeur de la
piste, déjà calculées par l'appelant sur le domaine de la jauge : la brique
ne connaît ni pourcentage ni donnée.
- la marque de seuil (2 px en `ink`) dépasse la piste de 6 px ; son
  étiquette (style `tick`, `ink-muted`) est au-dessus ;
- le repère de comparaison (2 px en `baseline`) dépasse de 3 px ; son
  étiquette est dessous ;
- une étiquette reste dans la largeur de la piste (elle se décale au lieu
  de déborder).

Le remplissage se joue en [SceneMotion.gauge] (`SceneOneShot`) au montage
puis à chaque changement de [fill] ; immédiat sous `SceneMotionScope`
`disabled`, et absent de l'animation si [settled] (surface restaurée). La
jauge porte son propre `RepaintBoundary`.''',
  stories: [
    $Blocking..$generatedName = 'Blocking',
    $Risk..$generatedName = 'Risk',
    $Ok..$generatedName = 'Ok',
    $Bare..$generatedName = 'Bare',
  ],
);
typedef DsGaugeScenario = Scenario<DsGauge, DsGaugeArgs>;
typedef DsGaugeDefaults = Defaults<DsGauge, DsGaugeArgs>;

class DsGaugeStory extends Story<DsGauge, DsGaugeArgs> {
  DsGaugeStory({
    super.name,
    super.designLink,
    SetupBuilder<DsGauge, DsGaugeArgs>? setup,
    super.modes,
    DsGaugeArgs? args,
    StoryWidgetBuilder<DsGauge, DsGaugeArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         args: args ?? DsGaugeArgs(),
         builder:
             builder ??
             (context, args) => DsGauge(
               key: args.key,
               fill: args.fill,
               fillColor: args.fillColor,
               mark: args.mark,
               markLabel: args.markLabel,
               reference: args.reference,
               referenceLabel: args.referenceLabel,
               settled: args.settled,
               keys: args.keys,
             ),
         setup: setup ?? defaults.setup!,
       );
}

class DsGaugeArgs extends StoryArgs<DsGauge> {
  DsGaugeArgs({
    Arg<Key?>? key,
    Arg<double>? fill,
    Arg<Color>? fillColor,
    Arg<double?>? mark,
    Arg<String?>? markLabel,
    Arg<double?>? reference,
    Arg<String?>? referenceLabel,
    Arg<bool>? settled,
    Arg<DsGaugeKeys>? keys,
  }) : this.keyArg = $initArg('key', key, null),
       this.fillArg = $initArg('fill', fill, DoubleArg(0.0))!,
       this.fillColorArg = $initArg(
         'fillColor',
         fillColor,
         ColorArg(const Color(4278190080)),
       )!,
       this.markArg = $initArg('mark', mark, NullableDoubleArg(null))!,
       this.markLabelArg = $initArg(
         'markLabel',
         markLabel,
         NullableStringArg(null),
       )!,
       this.referenceArg = $initArg(
         'reference',
         reference,
         NullableDoubleArg(null),
       )!,
       this.referenceLabelArg = $initArg(
         'referenceLabel',
         referenceLabel,
         NullableStringArg(null),
       )!,
       this.settledArg = $initArg('settled', settled, BoolArg(false))!,
       this.keysArg = $initArg('keys', keys, ConstArg(const DsGaugeKeys()))!;

  DsGaugeArgs.fixed({
    Key? key,
    double fill = 0.0,
    Color fillColor = const Color(4278190080),
    double? mark = null,
    String? markLabel = null,
    double? reference = null,
    String? referenceLabel = null,
    bool settled = false,
    DsGaugeKeys keys = const DsGaugeKeys(),
  }) : this.keyArg = $initArg('key', key == null ? null : Arg.fixed(key), null),
       this.fillArg = $initArg('fill', Arg.fixed(fill), null)!,
       this.fillColorArg = $initArg('fillColor', Arg.fixed(fillColor), null)!,
       this.markArg = $initArg(
         'mark',
         mark == null ? null : Arg.fixed(mark),
         null,
       ),
       this.markLabelArg = $initArg(
         'markLabel',
         markLabel == null ? null : Arg.fixed(markLabel),
         null,
       ),
       this.referenceArg = $initArg(
         'reference',
         reference == null ? null : Arg.fixed(reference),
         null,
       ),
       this.referenceLabelArg = $initArg(
         'referenceLabel',
         referenceLabel == null ? null : Arg.fixed(referenceLabel),
         null,
       ),
       this.settledArg = $initArg('settled', Arg.fixed(settled), null)!,
       this.keysArg = $initArg('keys', Arg.fixed(keys), null)!;

  final Arg<Key?>? keyArg;

  final Arg<double> fillArg;

  final Arg<Color> fillColorArg;

  final Arg<double?>? markArg;

  final Arg<String?>? markLabelArg;

  final Arg<double?>? referenceArg;

  final Arg<String?>? referenceLabelArg;

  final Arg<bool> settledArg;

  final Arg<DsGaugeKeys> keysArg;

  Key? get key => keyArg?.value;

  double get fill => fillArg.value;

  Color get fillColor => fillColorArg.value;

  double? get mark => markArg?.value;

  String? get markLabel => markLabelArg?.value;

  double? get reference => referenceArg?.value;

  String? get referenceLabel => referenceLabelArg?.value;

  bool get settled => settledArg.value;

  DsGaugeKeys get keys => keysArg.value;

  @override
  List<Arg?> get list => [
    keyArg,
    fillArg,
    fillColorArg,
    markArg,
    markLabelArg,
    referenceArg,
    referenceLabelArg,
    settledArg,
    keysArg,
  ];
}
