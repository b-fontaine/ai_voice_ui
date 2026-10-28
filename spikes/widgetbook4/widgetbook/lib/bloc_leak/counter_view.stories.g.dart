// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'counter_view.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<CounterView, StoryArgs<CounterView>>;
typedef _Scenario = CounterViewScenario;
typedef _Defaults = CounterViewDefaults;
typedef _Story = CounterViewStory;
typedef _Args = CounterViewArgs;
final CounterViewComponent = Component<CounterView, StoryArgs<CounterView>>(
  name: 'CounterView',
  path: 'bloc_leak',
  docComment: r'''Vue « feature » qui lit le Bloc fourni par un ancêtre.''',
  stories: [
    $SetupZero..$generatedName = 'SetupZero',
    $SetupHundred..$generatedName = 'SetupHundred',
    $KeyedZero..$generatedName = 'KeyedZero',
    $KeyedHundred..$generatedName = 'KeyedHundred',
  ],
);
typedef CounterViewScenario = Scenario<CounterView, CounterViewArgs>;
typedef CounterViewDefaults = Defaults<CounterView, CounterViewArgs>;

class CounterViewStory extends Story<CounterView, CounterViewArgs> {
  CounterViewStory({
    super.name,
    super.designLink,
    super.setup,
    super.modes,
    CounterViewArgs? args,
    StoryWidgetBuilder<CounterView, CounterViewArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         args: args ?? CounterViewArgs(),
         builder: builder ?? (context, args) => CounterView(key: args.key),
       );
}

class CounterViewArgs extends StoryArgs<CounterView> {
  CounterViewArgs({Arg<Key?>? key}) : this.keyArg = $initArg('key', key, null);

  CounterViewArgs.fixed({Key? key})
    : this.keyArg = $initArg('key', key == null ? null : Arg.fixed(key), null);

  final Arg<Key?>? keyArg;

  Key? get key => keyArg?.value;

  @override
  List<Arg?> get list => [keyArg];
}
