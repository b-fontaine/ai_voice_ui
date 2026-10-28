// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'ds_button.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<DsButton, StoryArgs<DsButton>>;
typedef _Scenario = DsButtonScenario;
typedef _Defaults = DsButtonDefaults;
typedef _Story = DsButtonStory;
typedef _Args = DsButtonArgs;
typedef _TonalScenario = DsButtonTonalScenario;
typedef _TonalDefaults = DsButtonTonalDefaults;
typedef _TonalStory = DsButtonTonalStory;
typedef _TonalArgs = DsButtonTonalArgs;
final DsButtonComponent = Component<DsButton, StoryArgs<DsButton>>(
  name: 'DsButton',
  path: 'ds',
  docComment: r'''Bouton du DS. Variantes par constructeurs nommés.''',
  stories: [
    $Default..$generatedName = 'Default',
    $Disabled..$generatedName = 'Disabled',
    $Tonal..$generatedName = 'Tonal',
  ],
);
typedef DsButtonScenario = Scenario<DsButton, DsButtonArgs>;
typedef DsButtonDefaults = Defaults<DsButton, DsButtonArgs>;

class DsButtonStory extends Story<DsButton, DsButtonArgs> {
  DsButtonStory({
    super.name,
    super.designLink,
    super.setup,
    super.modes,
    DsButtonArgs? args,
    StoryWidgetBuilder<DsButton, DsButtonArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         args: args ?? DsButtonArgs(),
         builder:
             builder ??
             (context, args) => DsButton(
               label: args.label,
               onPressed: args.onPressed,
               icon: args.icon,
               key: args.key,
             ),
       );
}

class DsButtonArgs extends StoryArgs<DsButton> {
  DsButtonArgs({
    Arg<String>? label,
    Arg<void Function()?>? onPressed,
    Arg<IconData?>? icon,
    Arg<Key?>? key,
  }) : this.labelArg = $initArg('label', label, StringArg(''))!,
       this.onPressedArg = $initArg('onPressed', onPressed, null),
       this.iconArg = $initArg('icon', icon, null),
       this.keyArg = $initArg('key', key, null);

  DsButtonArgs.fixed({
    String label = '',
    void Function()? onPressed,
    IconData? icon,
    Key? key,
  }) : this.labelArg = $initArg('label', Arg.fixed(label), null)!,
       this.onPressedArg = $initArg(
         'onPressed',
         onPressed == null ? null : Arg.fixed(onPressed),
         null,
       ),
       this.iconArg = $initArg(
         'icon',
         icon == null ? null : Arg.fixed(icon),
         null,
       ),
       this.keyArg = $initArg('key', key == null ? null : Arg.fixed(key), null);

  final Arg<String> labelArg;

  final Arg<void Function()?>? onPressedArg;

  final Arg<IconData?>? iconArg;

  final Arg<Key?>? keyArg;

  String get label => labelArg.value;

  void Function()? get onPressed => onPressedArg?.value;

  IconData? get icon => iconArg?.value;

  Key? get key => keyArg?.value;

  @override
  List<Arg?> get list => [labelArg, onPressedArg, iconArg, keyArg];
}

typedef DsButtonTonalScenario = Scenario<DsButton, DsButtonTonalArgs>;
typedef DsButtonTonalDefaults = Defaults<DsButton, DsButtonTonalArgs>;

class DsButtonTonalStory extends Story<DsButton, DsButtonTonalArgs> {
  DsButtonTonalStory({
    super.name,
    super.designLink,
    super.setup,
    super.modes,
    DsButtonTonalArgs? args,
    StoryWidgetBuilder<DsButton, DsButtonTonalArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         args: args ?? DsButtonTonalArgs(),
         builder:
             builder ??
             (context, args) => DsButton.tonal(
               label: args.label,
               onPressed: args.onPressed,
               icon: args.icon,
               key: args.key,
             ),
       );
}

class DsButtonTonalArgs extends StoryArgs<DsButton> {
  DsButtonTonalArgs({
    Arg<String>? label,
    Arg<void Function()?>? onPressed,
    Arg<IconData?>? icon,
    Arg<Key?>? key,
  }) : this.labelArg = $initArg('label', label, StringArg(''))!,
       this.onPressedArg = $initArg('onPressed', onPressed, null),
       this.iconArg = $initArg('icon', icon, null),
       this.keyArg = $initArg('key', key, null);

  DsButtonTonalArgs.fixed({
    String label = '',
    void Function()? onPressed,
    IconData? icon,
    Key? key,
  }) : this.labelArg = $initArg('label', Arg.fixed(label), null)!,
       this.onPressedArg = $initArg(
         'onPressed',
         onPressed == null ? null : Arg.fixed(onPressed),
         null,
       ),
       this.iconArg = $initArg(
         'icon',
         icon == null ? null : Arg.fixed(icon),
         null,
       ),
       this.keyArg = $initArg('key', key == null ? null : Arg.fixed(key), null);

  final Arg<String> labelArg;

  final Arg<void Function()?>? onPressedArg;

  final Arg<IconData?>? iconArg;

  final Arg<Key?>? keyArg;

  String get label => labelArg.value;

  void Function()? get onPressed => onPressedArg?.value;

  IconData? get icon => iconArg?.value;

  Key? get key => keyArg?.value;

  @override
  List<Arg?> get list => [labelArg, onPressedArg, iconArg, keyArg];
}
