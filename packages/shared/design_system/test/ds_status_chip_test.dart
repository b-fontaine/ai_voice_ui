import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';
import 'package:testing_real_fonts/testing_real_fonts.dart';

Widget _host(Widget child) => MaterialApp(
  theme: ThemeData(extensions: const [SceneTheme.dark()]),
  home: Scaffold(body: Center(child: child)),
);

/// Premier `DecoratedBox` de la puce : la pilule elle-même.
BoxDecoration _pill(WidgetTester tester) {
  final DecoratedBox box = tester.widget<DecoratedBox>(
    find
        .descendant(
          of: find.byType(DsStatusChip),
          matching: find.byType(DecoratedBox),
        )
        .first,
  );
  return box.decoration as BoxDecoration;
}

TextStyle _wordStyle(WidgetTester tester, String shown) => tester
    .renderObject<RenderParagraph>(
      find.descendant(of: find.text(shown), matching: find.byType(RichText)),
    )
    .text
    .style!;

void main() {
  const SceneTheme theme = SceneTheme.dark();
  final Map<SceneStatus?, Color> fills = <SceneStatus?, Color>{
    SceneStatus.ok: theme.okBackground,
    SceneStatus.risk: theme.riskBackground,
    SceneStatus.blocking: theme.blockingBackground,
    null: theme.neutralBackground,
  };
  final Map<SceneStatus?, Color> words = <SceneStatus?, Color>{
    SceneStatus.ok: theme.okForeground,
    SceneStatus.risk: theme.riskForeground,
    SceneStatus.blocking: theme.blockingForeground,
    null: theme.neutralForeground,
  };

  group('forme (gc-badge)', () {
    for (final SceneStatus? status in fills.keys) {
      testWidgets('26 px de haut, pilule, statut ${status?.name}', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(DsStatusChip(key: const Key('c'), status: status, label: 'Go')),
        );
        expect(tester.getSize(find.byKey(const Key('c'))).height, 26);
        expect(_pill(tester).borderRadius, SceneRadius.borderPill);
      });

      testWidgets('grande puce : 40 px, statut ${status?.name}', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(
            DsStatusChip(
              key: const Key('c'),
              status: status,
              label: 'Go',
              large: true,
            ),
          ),
        );
        expect(tester.getSize(find.byKey(const Key('c'))).height, 40);
        expect(_pill(tester).borderRadius, SceneRadius.borderPill);
      });
    }

    testWidgets('padding horizontal 11 (grande : 18) autour du mot', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const DsStatusChip(
            key: Key('c'),
            status: SceneStatus.risk,
            label: 'Go',
          ),
        ),
      );
      final double word = tester.getSize(find.text('GO')).width;
      // 2 px de bordure + 2 × 11 de remplissage.
      expect(tester.getSize(find.byKey(const Key('c'))).width, word + 2 + 22);

      await tester.pumpWidget(
        _host(
          const DsStatusChip(
            key: Key('c'),
            status: SceneStatus.risk,
            label: 'Go',
            large: true,
          ),
        ),
      );
      final double bigWord = tester.getSize(find.text('GO')).width;
      expect(
        tester.getSize(find.byKey(const Key('c'))).width,
        bigWord + 2 + 36,
      );
    });

    testWidgets('bordure de 1 px à la couleur du texte (currentColor)', (
      tester,
    ) async {
      for (final SceneStatus? status in <SceneStatus?>[
        SceneStatus.ok,
        SceneStatus.risk,
        SceneStatus.blocking,
      ]) {
        await tester.pumpWidget(
          _host(DsStatusChip(status: status, label: 'Mot')),
        );
        final Border border = _pill(tester).border! as Border;
        expect(border.top.width, 1, reason: '${status?.name}');
        expect(border.top.color, words[status], reason: '${status?.name}');
        expect(_wordStyle(tester, 'MOT').color, words[status]);
      }
    });

    testWidgets(
      'statut inconnu : surface-300, ink-muted, bordure line-strong',
      (tester) async {
        await tester.pumpWidget(
          _host(const DsStatusChip(status: null, label: 'x')),
        );
        final BoxDecoration d = _pill(tester);
        expect(d.color, theme.surface300);
        expect(d.color, theme.neutralBackground);
        expect((d.border! as Border).top.color, theme.lineStrong);
        expect(_wordStyle(tester, 'X').color, theme.textSecondary);
        expect(_wordStyle(tester, 'X').color, isNot(theme.inkFaint));
      },
    );

    for (final SceneStatus? status in fills.keys) {
      testWidgets('fond ghost et couleur du mot, statut ${status?.name}', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(DsStatusChip(status: status, label: 'Mot')),
        );
        expect(_pill(tester).color, fills[status]);
        expect(_wordStyle(tester, 'MOT').color, words[status]);
        expect(_wordStyle(tester, 'MOT').color, isNot(theme.inkFaint));
      });
    }
  });

  group('texte', () {
    testWidgets('police badge 12 px (badgeLg 18 px pour la grande puce)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const DsStatusChip(status: SceneStatus.risk, label: 'Mot')),
      );
      TextStyle s = _wordStyle(tester, 'MOT');
      expect(s.fontSize, theme.micro.badge.fontSize);
      expect(s.fontSize, 12);
      expect(s.letterSpacing, theme.micro.badge.letterSpacing);

      await tester.pumpWidget(
        _host(
          const DsStatusChip(
            status: SceneStatus.risk,
            label: 'Mot',
            large: true,
          ),
        ),
      );
      s = _wordStyle(tester, 'MOT');
      expect(s.fontSize, theme.micro.badgeLg.fontSize);
      expect(s.fontSize, 18);
      expect(s.letterSpacing, theme.micro.badgeLg.letterSpacing);
    });

    testWidgets('capitales à l affichage, libellé d origine en Semantics', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          const DsStatusChip(status: SceneStatus.risk, label: 'À risque (x)'),
        ),
      );
      expect(find.text('À RISQUE (X)'), findsOneWidget);
      expect(find.text('À risque (x)'), findsNothing);
      expect(
        tester.getSemantics(findTextIgnoringCase('À risque (x)')).label,
        'À risque (x)',
      );
      expect(find.bySemanticsLabel('À RISQUE (X)'), findsNothing);
      handle.dispose();
    });
  });

  group('glyphe et point', () {
    testWidgets('✓ pour ok seulement, 12 px, hors sémantique', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      for (final SceneStatus? status in fills.keys) {
        await tester.pumpWidget(
          _host(DsStatusChip(status: status, label: 'Validé')),
        );
        expect(
          find.text('✓'),
          status == SceneStatus.ok ? findsOneWidget : findsNothing,
          reason: 'statut ${status?.name}',
        );
        if (status == SceneStatus.ok) {
          expect(_wordStyle(tester, '✓').color, theme.okForeground);
          expect(_wordStyle(tester, '✓').fontSize, 12);
          expect(
            find.ancestor(
              of: find.text('✓'),
              matching: find.byType(ExcludeSemantics),
            ),
            findsWidgets,
          );
          expect(find.bySemanticsLabel(RegExp('✓')), findsNothing);
          expect(
            tester.getSemantics(findTextIgnoringCase('Validé')).label,
            'Validé',
          );
        }
      }
      handle.dispose();
    });

    Finder dot() => find.descendant(
      of: find.byType(DsStatusChip),
      matching: find.byWidgetPredicate(
        (Widget w) =>
            w is CustomPaint &&
            w.size == const Size.square(DsStatusChip.dotSize),
      ),
    );

    testWidgets('le point fait 6 px et n existe que pour Bloquant', (
      tester,
    ) async {
      expect(DsStatusChip.dotSize, 6);
      for (final SceneStatus? status in fills.keys) {
        await tester.pumpWidget(
          _host(DsStatusChip(status: status, label: 'Mot')),
        );
        expect(
          dot(),
          status == SceneStatus.blocking ? findsOneWidget : findsNothing,
          reason: 'statut ${status?.name}',
        );
      }
    });

    testWidgets('seul Bloquant bat (1,6 s), les autres statuts sont immobiles', (
      tester,
    ) async {
      for (final SceneStatus? status in fills.keys) {
        await tester.pumpWidget(
          _host(DsStatusChip(status: status, label: 'Mot')),
        );
        // Un battement : un `AnimatedWidget` ou un `CustomPainter` (un
        // `Listenable`) qui notifie entre deux images, tant qu'il est en cours.
        final List<Listenable> listenables = find
            .descendant(
              of: find.byType(DsStatusChip),
              matching: find.byWidgetPredicate(
                (Widget w) =>
                    (w is AnimatedWidget &&
                        w.listenable is Animation<double>) ||
                    (w is CustomPaint && w.painter != null),
              ),
            )
            .evaluate()
            .map(
              (Element e) => switch (e.widget) {
                AnimatedWidget(:final Listenable listenable) => listenable,
                CustomPaint(:final CustomPainter painter?) => painter,
                _ => throw StateError('widget inattendu'),
              },
            )
            .toList();
        var notifications = 0;
        void count() => notifications++;
        for (final Listenable l in listenables) {
          l.addListener(count);
        }
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        for (final Listenable l in listenables) {
          l.removeListener(count);
        }
        final bool beats = notifications > 0 && tester.hasRunningAnimations;
        expect(
          beats,
          status == SceneStatus.blocking,
          reason: 'statut ${status?.name}',
        );
        if (status != SceneStatus.blocking) {
          expect(tester.hasRunningAnimations, isFalse);
        }
      }
    });

    testWidgets('sous disabled : point plein, sans halo, aucune animation', (
      tester,
    ) async {
      Widget chip({required bool disabled}) => _host(
        SceneMotionScope(
          disabled: disabled,
          child: const DsStatusChip(status: SceneStatus.blocking, label: 'Mot'),
        ),
      );
      await tester.pumpWidget(chip(disabled: false));
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        tester.renderObject(dot()),
        paintsExactlyCountTimes(#drawCircle, 2),
      );

      await tester.pumpWidget(chip(disabled: true));
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
      expect(
        tester.renderObject(dot()),
        paintsExactlyCountTimes(#drawCircle, 1),
      );
    });

    testWidgets('le point est isolé (RepaintBoundary) et hors sémantique', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const DsStatusChip(status: SceneStatus.blocking, label: 'Mot')),
      );
      expect(
        find.ancestor(of: dot(), matching: find.byType(RepaintBoundary)),
        findsWidgets,
      );
      expect(
        find.ancestor(of: dot(), matching: find.byType(ExcludeSemantics)),
        findsWidgets,
      );
    });
  });

  group('lueur du verdict', () {
    testWidgets('grande puce bloquante : glow-nogo, sinon aucune ombre', (
      tester,
    ) async {
      Future<List<BoxShadow>?> shadow(SceneStatus? s, bool large) async {
        await tester.pumpWidget(
          _host(DsStatusChip(status: s, label: 'Mot', large: large)),
        );
        return _pill(tester).boxShadow;
      }

      expect(await shadow(SceneStatus.blocking, true), SceneShadow.glowNogo);
      expect(await shadow(SceneStatus.blocking, false), anyOf(isNull, isEmpty));
      expect(await shadow(SceneStatus.ok, true), anyOf(isNull, isEmpty));
      expect(await shadow(SceneStatus.risk, true), anyOf(isNull, isEmpty));
      expect(await shadow(null, true), anyOf(isNull, isEmpty));
    });
  });

  group('measure', () {
    for (final bool large in <bool>[false, true]) {
      for (final SceneStatus? status in fills.keys) {
        testWidgets('measure = taille réelle (${status?.name}, large=$large)', (
          tester,
        ) async {
          late BuildContext captured;
          await tester.pumpWidget(
            _host(
              Builder(
                builder: (BuildContext context) {
                  captured = context;
                  return DsStatusChip(
                    key: const Key('chip'),
                    status: status,
                    label: 'Validé',
                    large: large,
                  );
                },
              ),
            ),
          );
          final Size measured = DsStatusChip.measure(
            captured,
            status,
            'Validé',
            large: large,
          );
          final Size actual = tester.getSize(find.byKey(const Key('chip')));
          expect(measured.width, closeTo(actual.width, 0.01));
          expect(measured.height, closeTo(actual.height, 0.01));
          expect(measured.height, large ? 40 : 26);
        });
      }
    }
  });
}
