import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

Widget _host(Widget child) => MaterialApp(
  theme: ThemeData(extensions: const [SceneTheme.dark()]),
  home: Scaffold(body: Center(child: child)),
);

double _fontSizeOf(WidgetTester tester, Finder f) {
  final paragraph = tester.renderObject<RenderParagraph>(f);
  return paragraph.text.style!.fontSize!;
}

void main() {
  testWidgets('DsSkeleton se rend, statique, pumpAndSettle termine', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const DsSkeleton(key: Key('sk'))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('sk')), findsOneWidget);
  });

  testWidgets('DsSkeleton animé reste désactivable par TickerMode', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const TickerMode(enabled: false, child: DsSkeleton(animate: true))),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('DsNeutralState affiche le message et une icône', (tester) async {
    await tester.pumpWidget(_host(const DsNeutralState()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final text = find.text('Données indisponibles');
    expect(text, findsOneWidget);
    expect(find.byType(Icon), findsOneWidget);
    // pdr-0087 / pdr-0088 F1 : échelle du design system (11 px au plus bas), plus de plancher de 24 px.
    expect(_fontSizeOf(tester, text), greaterThanOrEqualTo(11));
  });

  testWidgets('DsStatusChip affiche le libellé tel quel', (tester) async {
    await tester.pumpWidget(
      _host(
        const DsStatusChip(
          status: SceneStatus.risk,
          label: 'À risque (libellé du backend)',
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final text = find.text('À risque (libellé du backend)');
    expect(text, findsOneWidget);
    // pdr-0087 / pdr-0088 F1 : échelle du design system (11 px au plus bas), plus de plancher de 24 px.
    expect(_fontSizeOf(tester, text), greaterThanOrEqualTo(11));
    final box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(DsStatusChip),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect(
      (box.decoration as BoxDecoration).color,
      const SceneTheme.dark().riskBackground,
    );
  });

  testWidgets('DsStatusChip sans statut utilise le style neutre', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const DsStatusChip(status: null, label: 'x')),
    );
    expect(tester.takeException(), isNull);
    final box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(DsStatusChip),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect(
      (box.decoration as BoxDecoration).color,
      const SceneTheme.dark().neutralBackground,
    );
  });

  testWidgets('DsStatusChip.verticalPadding est le remplissage vertical réel', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const DsStatusChip(key: Key('chip'), status: null, label: 'Go')),
    );
    expect(
      tester.getSize(find.byKey(const Key('chip'))).height -
          tester.getSize(find.text('Go')).height,
      2 * DsStatusChip.verticalPadding,
    );
  });

  group('DsStatusChip : statuts du design system (U6)', () {
    const theme = SceneTheme.dark();
    final fills = <SceneStatus?, Color>{
      SceneStatus.ok: theme.okBackground,
      SceneStatus.risk: theme.riskBackground,
      SceneStatus.blocking: theme.blockingBackground,
      null: theme.neutralBackground,
    };
    final words = <SceneStatus?, Color>{
      SceneStatus.ok: theme.okForeground,
      SceneStatus.risk: theme.riskForeground,
      SceneStatus.blocking: theme.blockingForeground,
      null: theme.neutralForeground,
    };

    for (final SceneStatus? status in fills.keys) {
      testWidgets('fond et couleur du mot du statut ${status?.name}', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(DsStatusChip(status: status, label: 'Mot')),
        );
        final box = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byType(DsStatusChip),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        expect((box.decoration as BoxDecoration).color, fills[status]);
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: find.text('Mot'),
            matching: find.byType(RichText),
          ),
        );
        expect(paragraph.text.style!.color, words[status]);
      });
    }

    testWidgets('le glyphe ✓ existe pour ok seulement, hors sémantique', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      for (final SceneStatus? status in fills.keys) {
        await tester.pumpWidget(
          _host(DsStatusChip(status: status, label: 'Validé')),
        );
        expect(
          find.text('✓'),
          status == SceneStatus.ok ? findsOneWidget : findsNothing,
          reason: 'statut ${status?.name}',
        );
        expect(find.text('Validé'), findsOneWidget);
        if (status == SceneStatus.ok) {
          final glyph = tester.renderObject<RenderParagraph>(
            find.descendant(
              of: find.text('✓'),
              matching: find.byType(RichText),
            ),
          );
          expect(glyph.text.style!.color, theme.okForeground);
          expect(
            find.ancestor(
              of: find.text('✓'),
              matching: find.byType(ExcludeSemantics),
            ),
            findsWidgets,
          );
          expect(tester.getSemantics(find.text('Validé')).label, 'Validé');
          expect(find.bySemanticsLabel(RegExp('✓')), findsNothing);
        }
      }
      handle.dispose();
    });

    testWidgets('seul Bloquant porte un point qui bat', (tester) async {
      for (final SceneStatus? status in fills.keys) {
        await tester.pumpWidget(
          _host(DsStatusChip(status: status, label: 'Mot')),
        );
        final beats = <SceneStatus?>{};
        final animations = find
            .descendant(
              of: find.byType(DsStatusChip),
              matching: find.byWidgetPredicate(
                (w) => w is AnimatedWidget && w.listenable is Animation<double>,
              ),
            )
            .evaluate()
            .map((e) => (e.widget as AnimatedWidget).listenable)
            .cast<Animation<double>>()
            .toList();
        final samples = <List<double>>[for (final _ in animations) <double>[]];
        for (var i = 0; i < 3; i++) {
          for (var k = 0; k < animations.length; k++) {
            samples[k].add(animations[k].value);
          }
          await tester.pump(const Duration(milliseconds: 300));
        }
        for (var k = 0; k < animations.length; k++) {
          final v = samples[k];
          if ((v[0] != v[1] || v[1] != v[2]) && animations[k].isAnimating) {
            beats.add(status);
          }
        }
        expect(
          beats,
          status == SceneStatus.blocking ? {SceneStatus.blocking} : isEmpty,
          reason: 'statut ${status?.name}',
        );
      }
    });

    testWidgets('le point de Bloquant s arrête sous disabled', (tester) async {
      await tester.pumpWidget(
        _host(
          const SceneMotionScope(
            disabled: true,
            child: DsStatusChip(status: SceneStatus.blocking, label: 'Mot'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('animations coupées en plein battement : aucun halo peint', (
      tester,
    ) async {
      Widget chip({required bool disabled}) => _host(
        SceneMotionScope(
          disabled: disabled,
          child: const DsStatusChip(status: SceneStatus.blocking, label: 'Mot'),
        ),
      );
      final Finder dot = find.descendant(
        of: find.byType(DsStatusChip),
        matching: find.byWidgetPredicate(
          (Widget w) =>
              w is CustomPaint &&
              w.size == const Size.square(DsStatusChip.dotSize),
        ),
      );
      await tester.pumpWidget(chip(disabled: false));
      await tester.pump(const Duration(milliseconds: 600));
      // En plein battement : halo et point.
      expect(tester.renderObject(dot), paintsExactlyCountTimes(#drawCircle, 2));

      await tester.pumpWidget(chip(disabled: true));
      await tester.pump();
      // Coupé : le point seul, sans halo figé à moitié estompé.
      expect(tester.renderObject(dot), paintsExactlyCountTimes(#drawCircle, 1));
    });

    testWidgets('le point de Bloquant est isolé et hors sémantique', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const DsStatusChip(status: SceneStatus.blocking, label: 'Mot')),
      );
      expect(
        find.descendant(
          of: find.byType(DsStatusChip),
          matching: find.byType(RepaintBoundary),
        ),
        findsWidgets,
      );
      expect(
        find.descendant(
          of: find.byType(DsStatusChip),
          matching: find.byType(ExcludeSemantics),
        ),
        findsWidgets,
      );
    });

    for (final SceneStatus? status in fills.keys) {
      testWidgets('measure = taille réelle de la puce ${status?.name}', (
        tester,
      ) async {
        late BuildContext captured;
        await tester.pumpWidget(
          _host(
            Builder(
              builder: (context) {
                captured = context;
                return DsStatusChip(
                  key: const Key('chip'),
                  status: status,
                  label: 'Validé',
                );
              },
            ),
          ),
        );
        final Size measured = DsStatusChip.measure(captured, status, 'Validé');
        final Size actual = tester.getSize(find.byKey(const Key('chip')));
        expect(measured.width, closeTo(actual.width, 0.01));
        expect(measured.height, closeTo(actual.height, 0.01));
      });
    }
  });
}
