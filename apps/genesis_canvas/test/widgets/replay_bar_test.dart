import 'package:feature_replay/feature_replay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_canvas/widgets/replay_bar/replay_bar.dart';

import '../support/replay_rig.dart';

const Key _play = Key('replay-play');
const Key _restart = Key('replay-restart');
const Key _slider = Key('replay-slider');
const Key _direct = Key('replay-direct');
const List<String> _speedIds = <String>['0.25', '0.5', '1', '1.5', '2'];

ReplayRig? _current;

/// Comme `testWidgets`, puis démonte l'arbre et ferme le Bloc (le lecteur ne
/// doit laisser aucun minuteur) avant les invariants du banc.
void barTest(
  String description,
  Future<void> Function(WidgetTester tester) body,
) => testWidgets(description, (WidgetTester tester) async {
  _current = null;
  await body(tester);
  await tester.pumpWidget(const SizedBox());
  _current?.dispose();
  await tester.pump();
});

Future<ReplayRig> _pump(
  WidgetTester tester, {
  required bool withJournal,
  double width = 480,
}) async {
  final ReplayRig rig = ReplayRig(withJournal: withJournal);
  _current = rig;
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<ReplayBloc>.value(
        value: rig.bloc,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, height: 140, child: const ReplayBar()),
        ),
      ),
    ),
  );
  await tester.pump();
  return rig;
}

bool _enabled(WidgetTester tester, Key key) {
  final Finder button = find.descendant(
    of: find.byKey(key),
    matching: find.byWidgetPredicate((Widget w) => w is ButtonStyleButton),
    matchRoot: true,
  );
  return tester.widget<ButtonStyleButton>(button).enabled;
}

bool _sliderEnabled(WidgetTester tester) =>
    tester.widget<Slider>(find.byKey(_slider)).onChanged != null;

Key _speedKey(String id) => Key('replay-speed-$id');

Future<void> _press(WidgetTester tester, Key key) async {
  await tester.tap(find.byKey(key));
  await tester.pump();
  await tester.pump();
}

void main() {
  barTest('Direct sans journal : tout est inactif, libellé REJEU', (
    tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await _pump(tester, withJournal: false);

    expect(find.byKey(const Key('replay-bar')), findsOneWidget);
    expect(find.text('REJEU'), findsOneWidget);
    expect(tester.getSemantics(find.byKey(_play)).label, 'Lecture');
    expect(_enabled(tester, _play), isFalse);
    expect(_enabled(tester, _restart), isFalse);
    expect(_enabled(tester, _direct), isFalse);
    expect(_sliderEnabled(tester), isFalse);
    for (final String id in _speedIds) {
      expect(_enabled(tester, _speedKey(id)), isFalse, reason: id);
    }
    semantics.dispose();
  });

  barTest('Direct avec journal jouable : seule Lecture est active', (
    tester,
  ) async {
    await _pump(tester, withJournal: true);

    expect(_enabled(tester, _play), isTrue);
    expect(_enabled(tester, _restart), isFalse);
    expect(_enabled(tester, _direct), isFalse);
    expect(_sliderEnabled(tester), isFalse);
    for (final String id in _speedIds) {
      expect(_enabled(tester, _speedKey(id)), isFalse, reason: id);
    }
  });

  barTest('Lecture entre en rejeu : Pause, puis Lecture, puis fin', (
    tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final ReplayRig rig = await _pump(tester, withJournal: true);

    await _press(tester, _play);
    expect(rig.router.mode, ReplayRouterMode.replay);
    expect(tester.getSemantics(find.byKey(_play)).label, 'Pause');
    expect(_enabled(tester, _restart), isTrue);
    expect(_enabled(tester, _direct), isTrue);
    expect(_sliderEnabled(tester), isTrue);
    for (final String id in _speedIds) {
      expect(_enabled(tester, _speedKey(id)), isTrue, reason: id);
    }

    await _press(tester, _play);
    expect(tester.getSemantics(find.byKey(_play)).label, 'Lecture');

    await _press(tester, _play);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    final ReplayActive ended = rig.bloc.state as ReplayActive;
    expect(ended.snapshot.status, ReplayStatus.ended);
    expect(tester.getSemantics(find.byKey(_play)).label, 'Lecture');
    final Slider slider = tester.widget<Slider>(find.byKey(_slider));
    expect(slider.value, slider.max, reason: 'curseur au bout');
    for (final String id in _speedIds) {
      expect(_enabled(tester, _speedKey(id)), isTrue, reason: '$id à la fin');
    }
    semantics.dispose();
  });

  barTest('un glisser du curseur ne produit qu\'un seul positionnement', (
    tester,
  ) async {
    final ReplayRig rig = await _pump(tester, withJournal: true);
    await _press(tester, _play);
    await _press(tester, _play); // pause
    final int before = rig.stage.clears;

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byKey(_slider)),
    );
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    expect(rig.stage.clears, before, reason: 'aucun seek pendant le glisser');
    await gesture.up();
    await tester.pump();
    await tester.pump();

    expect(rig.stage.clears, before + 1, reason: 'un seul seek, au relâché');
    final ReplayActive active = rig.bloc.state as ReplayActive;
    expect(active.snapshot.position, greaterThan(Duration.zero));
  });

  barTest('une pastille de vitesse choisit la vitesse et se met en évidence', (
    tester,
  ) async {
    final ReplayRig rig = await _pump(tester, withJournal: true);
    await _press(tester, _play);
    expect(
      find.descendant(
        of: find.byKey(_speedKey('1')),
        matching: find.byType(FilledButton),
        matchRoot: true,
      ),
      findsOneWidget,
      reason: '1x est la pastille courante',
    );

    await _press(tester, _speedKey('0.25'));

    expect((rig.bloc.state as ReplayActive).snapshot.speed, 0.25);
    expect(
      find.descendant(
        of: find.byKey(_speedKey('0.25')),
        matching: find.byType(FilledButton),
        matchRoot: true,
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(_speedKey('1')),
        matching: find.byType(FilledButton),
        matchRoot: true,
      ),
      findsNothing,
    );
    for (final String label in <String>['0,25×', '0,5×', '1×', '1,5×', '2×']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  barTest('Recommencer repart de zéro en lecture', (tester) async {
    final ReplayRig rig = await _pump(tester, withJournal: true);
    await _press(tester, _play);
    await tester.pump(const Duration(seconds: 1));
    final int before = rig.stage.clears;

    await _press(tester, _restart);

    expect(rig.stage.clears, before + 1);
    expect(
      (rig.bloc.state as ReplayActive).snapshot.status,
      ReplayStatus.playing,
    );
  });

  barTest('Direct quitte le rejeu', (tester) async {
    final ReplayRig rig = await _pump(tester, withJournal: true);
    await _press(tester, _play);

    await _press(tester, _direct);

    expect(rig.stage.exits, 1);
    expect(rig.router.mode, ReplayRouterMode.live);
    expect(rig.bloc.state, isA<ReplayLive>());
    expect(_enabled(tester, _direct), isFalse);
  });

  for (final bool active in <bool>[false, true]) {
    barTest('aucun débordement à 480 x 140, textes >= 24 px, cibles >= 48 px '
        '(${active ? 'rejeu' : 'direct'})', (tester) async {
      await _pump(tester, withJournal: true);
      if (active) await _press(tester, _play);

      expect(tester.takeException(), isNull);
      final Finder bar = find.byKey(const Key('replay-bar'));
      expect(tester.getSize(bar).width, lessThanOrEqualTo(480));
      expect(tester.getSize(bar).height, lessThanOrEqualTo(140));
      for (final Element e
          in find.descendant(of: bar, matching: find.byType(Text)).evaluate()) {
        final TextStyle style = DefaultTextStyle.of(e).style
            .merge((e.widget as Text).style);
        expect(style.fontSize, greaterThanOrEqualTo(24));
      }
      for (final Key key in <Key>[
        _play,
        _restart,
        _direct,
        _slider,
        ..._speedIds.map(_speedKey),
      ]) {
        expect(
          tester.getSize(find.byKey(key)).height,
          greaterThanOrEqualTo(48),
          reason: '$key',
        );
      }
    });
  }
}
