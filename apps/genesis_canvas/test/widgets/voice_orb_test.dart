import 'dart:io';

import 'package:flutter/material.dart' show Theme, ThemeData;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_canvas/widgets/top_bar/top_bar.dart';
import 'package:shared_design_system/shared_design_system.dart'
    show SceneMotionScope, SceneTheme;

const Key _orbKey = Key('voice-orb');

Widget _host(
  ValueNotifier<double> level, {
  bool thinking = false,
  bool interrupted = false,
  bool listening = false,
  bool micMuted = false,
}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(
    child: VoiceOrb(
      level: level,
      thinking: thinking,
      interrupted: interrupted,
      listening: listening,
      micMuted: micMuted,
    ),
  ),
);

/// Appels de dessin du painter de l'orbe à l'instant courant.
List<RecordedInvocation> _draw(WidgetTester tester) {
  final render = tester.renderObject<RenderCustomPaint>(
    find
        .descendant(of: find.byKey(_orbKey), matching: find.byType(CustomPaint))
        .first, // le painter de l'orbe précède celui du voile
  );
  final canvas = TestRecordingCanvas();
  render.painter!.paint(canvas, const Size.square(VoiceOrb.diameter));
  return canvas.invocations;
}

Iterable<RecordedInvocation> _named(
  List<RecordedInvocation> calls,
  Symbol name,
) => calls.where((c) => c.invocation.memberName == name);

// Le corps est le dernier disque : en parole, le halo est peint avant lui.
double _bodyRadius(List<RecordedInvocation> calls) =>
    _named(calls, #drawCircle).last.invocation.positionalArguments[1] as double;

double _arcStart(List<RecordedInvocation> calls) =>
    _named(calls, #drawArc).first.invocation.positionalArguments[1] as double;

String? _state(WidgetTester tester) =>
    tester.getSemantics(find.byKey(_orbKey)).value;

void main() {
  late ValueNotifier<double> level;

  setUp(() => level = ValueNotifier<double>(0));
  tearDown(() => level.dispose());

  testWidgets('expose le niveau reçu et garde sa taille de base', (
    tester,
  ) async {
    await tester.pumpWidget(_host(level));

    final orb = tester.widget<VoiceOrb>(find.byKey(_orbKey));
    expect(orb.level, same(level));
    expect(tester.getSize(find.byKey(_orbKey)), const Size.square(64));
  });

  testWidgets('repos : pulsation lente, aucun arc', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_host(level));

    final radii = <double>[];
    for (var i = 0; i < 8; i++) {
      radii.add(_bodyRadius(_draw(tester)));
      await tester.pump(const Duration(milliseconds: 250));
    }

    expect(radii.toSet().length, greaterThan(1), reason: 'le rayon pulse');
    expect(radii.every((r) => r > 0 && r <= VoiceOrb.diameter / 2), isTrue);
    expect(_named(_draw(tester), #drawArc), isEmpty);
    expect(_state(tester), 'repos');
    semantics.dispose();
  });

  testWidgets('parole : le rayon suit le niveau au-dessus du seuil', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_host(level));

    level.value = 0.2;
    await tester.pump(const Duration(milliseconds: 16));
    final low = _bodyRadius(_draw(tester));
    // Le rayon ne dépend pas de la phase de pulsation.
    await tester.pump(const Duration(milliseconds: 300));
    expect(_bodyRadius(_draw(tester)), low);

    level.value = 0.8;
    await tester.pump(const Duration(milliseconds: 16));
    final high = _bodyRadius(_draw(tester));

    expect(high, greaterThan(low));
    expect(high, lessThanOrEqualTo(VoiceOrb.diameter / 2));
    expect(_state(tester), 'parole');
    semantics.dispose();
  });

  testWidgets('un niveau sous le seuil reste au repos', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_host(level));

    level.value = 0.02;
    await tester.pump(const Duration(milliseconds: 16));

    expect(_state(tester), 'repos');
    semantics.dispose();
  });

  testWidgets('retour au repos quand le niveau retombe', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_host(level));
    level.value = 0.5;
    await tester.pump(const Duration(milliseconds: 16));
    expect(_state(tester), 'parole');

    level.value = 0;
    await tester.pump(const Duration(milliseconds: 16));

    expect(_state(tester), 'repos');
    semantics.dispose();
  });

  testWidgets('réflexion : un arc tourne', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_host(level, thinking: true));

    final first = _arcStart(_draw(tester));
    await tester.pump(const Duration(milliseconds: 300));
    final later = _arcStart(_draw(tester));

    expect(later, isNot(first));
    expect(_state(tester), 'réflexion');
    semantics.dispose();
  });

  testWidgets('la parole prime sur la réflexion', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_host(level, thinking: true));

    level.value = 0.6;
    await tester.pump(const Duration(milliseconds: 16));

    expect(_state(tester), 'parole');
    expect(_named(_draw(tester), #drawArc), isEmpty);
    semantics.dispose();
  });

  testWidgets("l'accessibilité porte le libellé « Orbe vocal »", (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_host(level));

    expect(tester.getSemantics(find.byKey(_orbKey)).label, 'Orbe vocal');
    semantics.dispose();
  });

  testWidgets("le changement de niveau repeint sans reconstruire l'orbe", (
    tester,
  ) async {
    var rebuilt = 0;
    final previous = debugOnRebuildDirtyWidget;
    debugOnRebuildDirtyWidget = (element, _) {
      if (element.widget is VoiceOrb) rebuilt++;
    };
    addTearDown(() => debugOnRebuildDirtyWidget = previous);
    await tester.pumpWidget(_host(level));
    final baseline = rebuilt;
    final render = tester.renderObject<RenderCustomPaint>(
      find.descendant(
        of: find.byKey(_orbKey),
        matching: find.byType(CustomPaint),
      ),
    );

    level.value = 0.4;

    expect(render.debugNeedsPaint, isTrue);
    await tester.pump(const Duration(milliseconds: 16));
    expect(rebuilt, baseline);
  });

  testWidgets("l'animation est arrêtée hors de vue (TickerMode)", (
    tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: TickerMode(enabled: false, child: VoiceOrb(level: level)),
      ),
    );
    await tester.pump();

    expect(tester.hasRunningAnimations, isFalse);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets("l'animation est libérée au démontage", (tester) async {
    await tester.pumpWidget(_host(level));
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pumpWidget(const SizedBox());

    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets("changer de niveau notifiant n'est pas retenu après démontage", (
    tester,
  ) async {
    await tester.pumpWidget(_host(level));
    await tester.pumpWidget(const SizedBox());

    // Aucun écouteur résiduel : ne doit rien lever.
    level.value = 0.9;
    await tester.pump();
  });

  group('interruption (FR-19, RG-17)', () {
    Color bodyColor(List<RecordedInvocation> calls) =>
        (_named(calls, #drawCircle).first.invocation.positionalArguments[2]
                as Paint)
            .color;

    testWidgets('interrompue : état lu, arrêt net sans pulsation ni arc', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_host(level, interrupted: true));

      final radii = <double>[];
      for (var i = 0; i < 6; i++) {
        radii.add(_bodyRadius(_draw(tester)));
        await tester.pump(const Duration(milliseconds: 250));
      }

      expect(_state(tester), 'Interrompue');
      expect(
        radii.toSet(),
        hasLength(1),
        reason: 'arrêt net, pas de pulsation',
      );
      expect(_named(_draw(tester), #drawArc), isEmpty);
      semantics.dispose();
    });

    testWidgets('interrompue : flash, couleur distincte du repos', (
      tester,
    ) async {
      await tester.pumpWidget(_host(level));
      final rest = bodyColor(_draw(tester));
      await tester.pumpWidget(_host(level, interrupted: true));

      expect(bodyColor(_draw(tester)), isNot(rest));
    });

    testWidgets('interrompue prime sur la parole et la réflexion', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_host(level, interrupted: true, thinking: true));
      level.value = 0.8;
      await tester.pump(const Duration(milliseconds: 16));

      expect(_state(tester), 'Interrompue');
      semantics.dispose();
    });

    testWidgets('écoute : lue au repos quand la session écoute', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_host(level, listening: true));

      expect(_state(tester), 'Écoute');

      level.value = 0.5;
      await tester.pump(const Duration(milliseconds: 16));
      expect(_state(tester), 'parole');
      semantics.dispose();
    });

    testWidgets('l\'état change quand interrupted change', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_host(level, interrupted: true));
      expect(_state(tester), 'Interrompue');

      await tester.pumpWidget(_host(level, listening: true));
      await tester.pump();
      expect(_state(tester), 'Écoute');
      semantics.dispose();
    });
  });

  group('voile « Micro coupé »', () {
    testWidgets('absent quand le micro est ouvert', (tester) async {
      await tester.pumpWidget(_host(level));
      expect(find.text('Micro coupé'), findsNothing);
    });

    testWidgets('posé par-dessus la phase réelle, sans la remplacer', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_host(level, listening: true, micMuted: true));

      expect(find.text('Micro coupé'), findsOneWidget);
      expect(find.byKey(const Key('mic-muted-veil')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('mic-muted-veil'))),
        const Size.square(64),
        reason: 'le disque voilé recouvre l\'orbe, sans le grandir',
      );
      // La phase reste lisible sous le voile.
      expect(_state(tester), 'Écoute');
      expect(_named(_draw(tester), #drawCircle), isNotEmpty);

      level.value = 0.8;
      await tester.pump(const Duration(milliseconds: 16));
      expect(_state(tester), 'parole');
      expect(find.text('Micro coupé'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('disparaît quand le micro est rétabli', (tester) async {
      await tester.pumpWidget(_host(level, micMuted: true));
      expect(find.text('Micro coupé'), findsOneWidget);
      await tester.pumpWidget(_host(level));
      expect(find.text('Micro coupé'), findsNothing);
    });

    testWidgets('le libellé fait 24 px au moins (RG-09) et ne déborde pas', (
      tester,
    ) async {
      await tester.pumpWidget(_host(level, micMuted: true));

      final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
        find.text('Micro coupé'),
      );
      expect(paragraph.text.style?.fontSize, greaterThanOrEqualTo(24));
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(tester.takeException(), isNull);
      // Sous le disque, dans les 104 points utiles de la barre du haut.
      final Rect veil = tester.getRect(find.byKey(const Key('mic-muted-veil')));
      final Rect label = tester.getRect(find.text('Micro coupé'));
      expect(label.top, greaterThanOrEqualTo(veil.bottom));
      expect(
        tester.getSize(find.byKey(_orbKey)).height,
        lessThanOrEqualTo(104),
      );
    });
  });

  group('réglage d\'animation de la scène', () {
    Widget scoped(
      ValueNotifier<double> level, {
      required bool disabled,
      double speed = 1,
      bool thinking = false,
    }) => SceneMotionScope(
      disabled: disabled,
      speed: speed,
      child: _host(level, thinking: thinking),
    );

    testWidgets('animations actives : la boucle tourne', (tester) async {
      await tester.pumpWidget(scoped(level, disabled: false));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
    });

    testWidgets('animations coupées : aucun Ticker actif, rayon fixe', (
      tester,
    ) async {
      await tester.pumpWidget(scoped(level, disabled: true));
      expect(tester.binding.transientCallbackCount, 0);
      final double radius = _bodyRadius(_draw(tester));
      await tester.pump(const Duration(seconds: 3));
      expect(_bodyRadius(_draw(tester)), radius);
      await tester.pumpAndSettle();
    });

    testWidgets('animations coupées en réflexion : l\'arc ne tourne pas', (
      tester,
    ) async {
      await tester.pumpWidget(scoped(level, disabled: true, thinking: true));
      final double start = _arcStart(_draw(tester));
      await tester.pump(const Duration(seconds: 1));
      expect(_arcStart(_draw(tester)), start);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('bascule de disabled : arrêt puis reprise', (tester) async {
      await tester.pumpWidget(scoped(level, disabled: false));
      await tester.pumpWidget(scoped(level, disabled: true));
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(scoped(level, disabled: false));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
    });

    testWidgets('vitesse de rejeu 2 : la pulsation va deux fois plus vite', (
      tester,
    ) async {
      await tester.pumpWidget(scoped(level, disabled: false, speed: 2));
      final double start = _bodyRadius(_draw(tester));
      // Une période de 2 s devient 1 s : retour au rayon de départ.
      await tester.pump(const Duration(seconds: 1));
      expect(_bodyRadius(_draw(tester)), closeTo(start, 0.01));
    });
  });

  group('couleurs du thème de scène (pdr-0083)', () {
    const SceneTheme base = SceneTheme.dark();
    const Color plasma = Color(0xFF123456);
    const Color ghost = Color(0x44654321);
    const Color ink = Color(0xFFFEDCBA);
    const Color veil = Color(0x99112233);

    Widget themed(Widget child, {SceneTheme? theme}) => Theme(
      data: ThemeData(extensions: <SceneTheme>[theme ?? base]),
      child: child,
    );

    final SceneTheme custom = base.copyWith(
      plasma: plasma,
      plasmaGhost: ghost,
      textPrimary: ink,
      orbVeil: veil,
    );

    Paint bodyPaint(WidgetTester tester) =>
        _named(
              _draw(tester),
              #drawCircle,
            ).last.invocation.positionalArguments[2]
            as Paint;

    testWidgets('repos : le corps prend la couleur plasma du thème', (
      tester,
    ) async {
      await tester.pumpWidget(themed(_host(level)));
      expect(bodyPaint(tester).color.toARGB32(), base.plasma.toARGB32());

      await tester.pumpWidget(themed(_host(level), theme: custom));
      expect(bodyPaint(tester).color.toARGB32(), plasma.toARGB32());
    });

    testWidgets("interrompue : l'éclair prend le texte principal du thème", (
      tester,
    ) async {
      await tester.pumpWidget(
        themed(_host(level, interrupted: true), theme: custom),
      );
      expect(bodyPaint(tester).color.toARGB32(), ink.toARGB32());
    });

    testWidgets("réflexion : l'arc prend la couleur plasma du thème", (
      tester,
    ) async {
      await tester.pumpWidget(
        themed(_host(level, thinking: true), theme: custom),
      );
      final Paint arc =
          _named(
                _draw(tester),
                #drawArc,
              ).first.invocation.positionalArguments[4]
              as Paint;
      expect(arc.color.toARGB32(), plasma.toARGB32());
    });

    testWidgets('micro coupé : le voile prend orbVeil', (tester) async {
      await tester.pumpWidget(
        themed(_host(level, micMuted: true), theme: custom),
      );
      final DecoratedBox box = tester.widget<DecoratedBox>(
        find.byKey(const Key('mic-muted-veil')),
      );
      expect(
        (box.decoration as BoxDecoration).color?.toARGB32(),
        veil.toARGB32(),
      );
    });

    testWidgets('un thème qui change repeint avec la nouvelle couleur', (
      tester,
    ) async {
      await tester.pumpWidget(themed(_host(level, thinking: true)));
      await tester.pumpWidget(
        themed(_host(level, thinking: true), theme: custom),
      );
      final calls = _draw(tester);
      expect(
        (_named(calls, #drawCircle).first.invocation.positionalArguments[2]
                as Paint)
            .color
            .toARGB32(),
        plasma.toARGB32(),
      );
    });

    testWidgets('parole : halo en dégradé radial, sans flou ni saveLayer', (
      tester,
    ) async {
      await tester.pumpWidget(themed(_host(level), theme: custom));
      level.value = 0.6;
      await tester.pump(const Duration(milliseconds: 16));

      final calls = _draw(tester);
      final circles = _named(calls, #drawCircle).toList();
      expect(circles, hasLength(2), reason: 'halo puis corps');
      final Paint halo =
          circles.first.invocation.positionalArguments[2] as Paint;
      final Paint body =
          circles.last.invocation.positionalArguments[2] as Paint;
      expect(halo.shader, isNotNull, reason: 'dégradé radial');
      expect(body.shader, isNull);
      expect(body.color.toARGB32(), plasma.toARGB32());
      for (final c in circles) {
        expect(
          (c.invocation.positionalArguments[2] as Paint).maskFilter,
          isNull,
        );
      }
      expect(_named(calls, #saveLayer), isEmpty);
    });

    testWidgets("l'intensité du halo suit le niveau audio", (tester) async {
      await tester.pumpWidget(themed(_host(level)));
      level.value = 0.1;
      await tester.pump(const Duration(milliseconds: 16));
      double haloScale() =>
          _named(_draw(tester), #scale).single.invocation.positionalArguments[0]
              as double;
      final low = haloScale();
      level.value = 0.5;
      await tester.pump(const Duration(milliseconds: 16));
      final mid = haloScale();

      expect(mid, greaterThan(low));
      expect(mid, lessThanOrEqualTo(VoiceOrb.diameter / 2));
    });

    testWidgets('au repos : un seul disque, sans halo', (tester) async {
      await tester.pumpWidget(themed(_host(level)));
      final circles = _named(_draw(tester), #drawCircle).toList();
      expect(circles, hasLength(1));
      expect(
        (circles.single.invocation.positionalArguments[2] as Paint).shader,
        isNull,
      );
    });

    test('la source ne contient ni MaskFilter ni ombre floue', () {
      final String source = File('lib/widgets/top_bar/voice_orb.dart')
          .readAsStringSync();
      expect(source, contains('RadialGradient'));
      expect(source, isNot(contains('MaskFilter')));
      expect(source, isNot(contains('BoxShadow')));
    });
  });
}
