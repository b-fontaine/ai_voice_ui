import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_canvas/widgets/top_bar/top_bar.dart';

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

double _bodyRadius(List<RecordedInvocation> calls) =>
    _named(calls, #drawCircle).first.invocation.positionalArguments[1]
        as double;

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
}
