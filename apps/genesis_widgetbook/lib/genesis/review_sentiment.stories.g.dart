// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'review_sentiment.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<ReviewSentiment, StoryArgs<ReviewSentiment>>;
typedef _Scenario = ReviewSentimentScenario;
typedef _Defaults = ReviewSentimentDefaults;
typedef _Story = ReviewSentimentStory;
typedef _Args = ReviewSentimentArgs;
final ReviewSentimentComponent =
    Component<ReviewSentiment, StoryArgs<ReviewSentiment>>(
      name: 'ReviewSentiment',
      path: 'genesis',
      docComment:
          r'''`ReviewSentiment` : surface `reviews` (`act1-reviews.jsonl`).''',
      stories: [
        $Data..$generatedName = 'Data',
        $NoData..$generatedName = 'NoData',
        $Neutral..$generatedName = 'Neutral',
      ],
    );
typedef ReviewSentimentScenario =
    Scenario<ReviewSentiment, ReviewSentimentArgs>;
typedef ReviewSentimentDefaults =
    Defaults<ReviewSentiment, ReviewSentimentArgs>;

class ReviewSentimentStory extends Story<ReviewSentiment, ReviewSentimentArgs> {
  ReviewSentimentStory({
    super.name,
    super.designLink,
    SetupBuilder<ReviewSentiment, ReviewSentimentArgs>? setup,
    super.modes,
    ReviewSentimentArgs? args,
    StoryWidgetBuilder<ReviewSentiment, ReviewSentimentArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         args: args ?? ReviewSentimentArgs(),
         builder:
             builder ??
             (context, args) =>
                 ReviewSentiment(key: args.key, state: args.state),
         setup: setup ?? defaults.setup!,
       );
}

class ReviewSentimentArgs extends StoryArgs<ReviewSentiment> {
  ReviewSentimentArgs({Arg<Key?>? key, Arg<GenesisSurfaceState>? state})
    : this.keyArg = $initArg('key', key, null),
      this.stateArg = $initArg(
        'state',
        state,
        EnumArg<GenesisSurfaceState>(
          GenesisSurfaceState.data,
          values: GenesisSurfaceState.values,
        ),
      )!;

  ReviewSentimentArgs.fixed({
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
