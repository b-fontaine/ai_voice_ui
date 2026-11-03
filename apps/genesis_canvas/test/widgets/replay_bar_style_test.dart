import 'package:feature_replay/feature_replay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_canvas/widgets/replay_bar/replay_bar.dart';
import 'package:shared_design_system/shared_design_system.dart';

import '../support/replay_rig.dart';

/// Apparence de la barre de rejeu (`gc-replay`, `gc-track`, `gc-speed`,
/// `gc-live`, FR-09, T33) : visuels de 34 et 26 points dans des cibles de
/// 48 points, piste de 4 points avec remplissage et poignée, vitesse
/// sélectionnée en `ink`, étiquette « Direct » avec son point. La logique et
/// les rectangles de 018 ne changent pas.
const SceneTheme _theme = SceneTheme.dark();

ReplayRig? _current;

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
  bool withJournal = true,
  bool motionDisabled = false,
}) async {
  final ReplayRig rig = ReplayRig(withJournal: withJournal);
  _current = rig;
  await tester.pumpWidget(
    MaterialApp(
      home: SceneMotionScope(
        disabled: motionDisabled,
        child: BlocProvider<ReplayBloc>.value(
          value: rig.bloc,
          child: const Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 480, height: 140, child: ReplayBar()),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return rig;
}

Finder _key(String name) => find.byKey(Key(name));

Future<void> _press(WidgetTester tester, String key) async {
  await tester.tap(_key(key));
  await tester.pump();
  await tester.pump();
}

BoxDecoration _decoration(WidgetTester tester, String key) =>
    tester
            .widget<DecoratedBox>(
              find
                  .descendant(
                    of: _key(key),
                    matching: find.byType(DecoratedBox),
                    matchRoot: true,
                  )
                  .first,
            )
            .decoration
        as BoxDecoration;

TextStyle _textStyle(WidgetTester tester, String key) => tester
    .widget<Text>(
      find
          .descendant(
            of: _key(key),
            matching: find.byType(Text),
            matchRoot: true,
          )
          .first,
    )
    .style!;

void main() {
  const List<String> speedIds = <String>['0.25', '0.5', '1', '1.5', '2'];

  barTest('boutons icône : visuel de 34 points, rayon md, fond surface-300, '
      'bordure ink-muted, dans une cible d\'au moins 48 points', (
    tester,
  ) async {
    await _pump(tester);

    for (final String name in <String>['play', 'restart']) {
      expect(
        tester.getSize(_key('replay-$name-visual')).height,
        34,
        reason: name,
      );
      final Size target = tester.getSize(_key('replay-$name'));
      expect(target.width, greaterThanOrEqualTo(48), reason: name);
      expect(target.height, greaterThanOrEqualTo(48), reason: name);
      final BoxDecoration d = _decoration(tester, 'replay-$name-visual');
      expect(d.borderRadius, SceneRadius.borderMd, reason: name);
      expect(d.color, _theme.surface300, reason: name);
      expect((d.border! as Border).top.color, _theme.textSecondary);
      expect(
        tester.getCenter(_key('replay-$name-visual')),
        tester.getCenter(_key('replay-$name')),
        reason: '$name : visuel centré dans sa cible',
      );
    }
  });

  barTest('piste de 4 points, remplissage signal, poignée ronde de 14 points '
      'ink avec lueur signal', (tester) async {
    await _pump(tester);

    expect(tester.getSize(_key('replay-track')).height, 4);
    expect(_decoration(tester, 'replay-track').color, _theme.surface300);
    expect(_decoration(tester, 'replay-track-fill').color, _theme.accent);
    final Size knob = tester.getSize(_key('replay-track-knob'));
    expect(knob, const Size(14, 14));
    final BoxDecoration k = _decoration(tester, 'replay-track-knob');
    expect(k.shape, BoxShape.circle);
    expect(k.color, _theme.textPrimary);
    expect(
      k.boxShadow!.any((BoxShadow s) => s.color.a > 0),
      isTrue,
      reason: 'lueur signal',
    );
  });

  barTest('en direct la piste est pleine ; en rejeu le remplissage et la '
      'poignée suivent la position', (tester) async {
    final ReplayRig rig = await _pump(tester);
    final Rect track = tester.getRect(_key('replay-track'));
    expect(tester.getRect(_key('replay-track-fill')).width, track.width);
    expect(tester.getCenter(_key('replay-track-knob')).dx, track.right);

    await _press(tester, 'replay-play');
    await _press(tester, 'replay-play'); // pause à zéro
    expect(tester.getRect(_key('replay-track-fill')).width, 0);
    expect(tester.getCenter(_key('replay-track-knob')).dx, track.left);

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(_key('replay-slider')),
    );
    await gesture.moveBy(const Offset(10, 0));
    await tester.pump();
    final double during = tester.getRect(_key('replay-track-fill')).width;
    expect(during, greaterThan(0), reason: 'le glisser suit le doigt');
    expect(
      tester.getCenter(_key('replay-track-knob')).dx,
      closeTo(track.left + during, 0.5),
    );
    await gesture.up();
    await tester.pump();
    await tester.pump();
    final ReplayActive active = rig.bloc.state as ReplayActive;
    final double fraction =
        active.snapshot.position.inMilliseconds /
        active.snapshot.duration.inMilliseconds;
    expect(
      tester.getRect(_key('replay-track-fill')).width,
      closeTo(track.width * fraction, 0.5),
    );
  });

  barTest('vitesses : segments de 26 points, rayon sm, bordure line, texte '
      'ink-muted en micro.speed, dans des cibles de 48 points', (tester) async {
    await _pump(tester);

    for (final String id in speedIds) {
      final String visual = 'replay-speed-$id-visual';
      expect(tester.getSize(_key(visual)).height, 26, reason: id);
      expect(
        tester.getSize(_key('replay-speed-$id')).height,
        greaterThanOrEqualTo(48),
        reason: id,
      );
    }
    final BoxDecoration d = _decoration(tester, 'replay-speed-0.25-visual');
    expect(d.borderRadius, SceneRadius.borderSm);
    expect(d.color, isNull, reason: 'fond transparent');
    expect((d.border! as Border).top.color, _theme.line);
    final TextStyle style = _textStyle(tester, 'replay-speed-0.25-visual');
    expect(style.color, _theme.textSecondary, reason: 'jamais ink-faint (F12)');
    expect(style.fontSize, _theme.micro.speed.fontSize);
    expect(style.fontFamily, _theme.micro.speed.fontFamily);
  });

  barTest('la vitesse sélectionnée a le fond ink, le texte void et la '
      'bordure ink ; une autre vitesse la déplace', (tester) async {
    await _pump(tester);
    BoxDecoration d = _decoration(tester, 'replay-speed-1-visual');
    expect(d.color, _theme.textPrimary, reason: 'direct : vitesse par défaut');
    expect((d.border! as Border).top.color, _theme.textPrimary);
    expect(
      _textStyle(tester, 'replay-speed-1-visual').color,
      _theme.background,
    );

    await _press(tester, 'replay-play');
    await _press(tester, 'replay-speed-0.5');

    d = _decoration(tester, 'replay-speed-0.5-visual');
    expect(d.color, _theme.textPrimary);
    expect(_decoration(tester, 'replay-speed-1-visual').color, isNull);
  });

  barTest('« Direct » : point signal de 6 points et texte signal en '
      'capitales, dans une cible de 48 points', (tester) async {
    await _pump(tester);

    expect(tester.getSize(_key('replay-direct-dot')), const Size(6, 6));
    expect(_decoration(tester, 'replay-direct-dot').shape, BoxShape.circle);
    expect(_decoration(tester, 'replay-direct-dot').color, _theme.accent);
    final Finder label = find.descendant(
      of: _key('replay-direct'),
      matching: find.text('DIRECT'),
    );
    expect(label, findsOneWidget);
    expect(tester.widget<Text>(label).style!.color, _theme.accent);
    expect(
      tester.getSize(_key('replay-direct')).height,
      greaterThanOrEqualTo(48),
    );
  });

  barTest('aucune boucle : rien ne tourne hors rejeu, ni sous '
      'disableAnimations', (tester) async {
    await _pump(tester, motionDisabled: true);
    expect(tester.hasRunningAnimations, isFalse);
    expect(tester.binding.transientCallbackCount, 0);
  });

  barTest('le rectangle de la barre est celui de 018', (tester) async {
    await _pump(tester);
    expect(
      tester.getRect(_key('replay-bar')),
      const Rect.fromLTWH(0, 0, 480, 140),
    );
  });
}
