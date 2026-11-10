import 'package:a2ui_core/a2ui_core.dart' show MessageProcessor;
import 'package:a2ui_flutter/a2ui_flutter.dart'
    show CatalogImplementation, ComponentImplementation;
import 'package:a2ui_flutter/v0_9/basic_catalog.dart' as v0_9;
import 'package:feature_canvas/feature_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

import '../support/messages.dart';

/// Port du cadre de génération (019 T32a, pdr-0088 F11) : la page dit quelle est
/// la dernière surface créée et son agent ; le canevas décide, d'après la phase
/// de chaque surface, qui porte le cadre. Un seul cadre est actif ; il se
/// termine à `data` ; une mutation de l'acte 2 n'en rouvre aucun.
void main() {
  const SceneTheme theme = SceneTheme.dark();
  late MessageProcessor<ComponentImplementation> controller;
  late CanvasBloc bloc;
  late ValueNotifier<GenerationTarget?> generation;
  late ValueNotifier<String?> highlight;

  /// [before] : messages appliqués avant le premier rendu (surfaces
  /// restaurées).
  Future<void> pumpBoard(
    WidgetTester tester, {
    bool animations = true,
    List<Object> before = const <Object>[],
  }) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(1872, 676);
    addTearDown(tester.view.reset);
    controller = MessageProcessor<ComponentImplementation>(
      catalogs: <CatalogImplementation>[v0_9.basicCatalog()],
    );
    bloc = CanvasBloc(controller);
    generation = ValueNotifier<GenerationTarget?>(null);
    highlight = ValueNotifier<String?>(null);
    addTearDown(() async {
      await bloc.close();
      controller.dispose();
      generation.dispose();
      highlight.dispose();
    });
    for (final Object m in before) {
      bloc.add(A2uiMessageReceived(m as dynamic));
    }
    if (before.isNotEmpty) await tester.runAsync(pumpEventQueue);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Theme(
          data: ThemeData(extensions: const <ThemeExtension<dynamic>>[theme]),
          child: SceneMotionScope(
            disabled: !animations,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 1872,
                height: 676,
                child: BlocProvider<CanvasBloc>.value(
                  value: bloc,
                  child: CanvasBoard(
                    controller: controller,
                    generation: generation,
                    highlight: highlight,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> send(WidgetTester tester, Iterable<Object> messages) async {
    for (final Object m in messages) {
      bloc.add(A2uiMessageReceived(m as dynamic));
    }
    for (int i = 0; i < 6; i++) {
      await tester.pump();
    }
  }

  Finder frame(String id) =>
      find.byKey(ValueKey<String>('generation-frame-$id'));
  Finder tag(String id) =>
      find.byKey(ValueKey<String>('generation-frame-$id-tag'));
  Finder anyFrame() => find.byWidgetPredicate((Widget w) {
    final Key? key = w.key;
    return key is ValueKey<String> &&
        RegExp(r'^generation-frame-[^-]+$').hasMatch(key.value);
  });

  /// Surface créée : le canevas et la page (port) en sont informés.
  Future<void> create(WidgetTester tester, String id, {String? agent}) async {
    generation.value = GenerationTarget(surfaceId: id, agent: agent);
    await send(tester, <Object>[createSurface(id)]);
  }

  String tagText(WidgetTester tester, String id) => tester
      .widgetList<Text>(
        find.descendant(of: tag(id), matching: find.byType(Text)),
      )
      .map((Text t) => t.data ?? '')
      .join(' ');

  group('port du cadre de génération', () {
    testWidgets('aucun cadre sans surface cible', (tester) async {
      await pumpBoard(tester);
      await send(tester, <Object>[createSurface('kpi')]);
      expect(anyFrame(), findsNothing);
      await tester.pump(const Duration(seconds: 4));
      expect(anyFrame(), findsNothing);
    });

    testWidgets('le cadre est sur la dernière surface créée, étiquette '
        '« Agent · génère » dans la cellule', (tester) async {
      await pumpBoard(tester);
      await create(tester, 'kpi', agent: 'Collecteur');
      await create(tester, 'trend', agent: 'Analyste');

      expect(anyFrame(), findsOneWidget);
      expect(frame('trend'), findsOneWidget);
      expect(frame('kpi'), findsNothing);
      expect(tagText(tester, 'trend').toLowerCase(), 'analyste · génère');
      final Rect cell = tester.getRect(
        find.byKey(const ValueKey<String>('surface-trend')),
      );
      final Rect pill = tester.getRect(tag('trend'));
      expect(
        cell.contains(pill.topLeft) && cell.contains(pill.bottomRight),
        isTrue,
        reason: 'l\'étiquette reste dans la cellule : $pill hors de $cell',
      );
      expect(
        pill.center.dx,
        greaterThan(cell.center.dx),
        reason: 'l\'étiquette est en haut à droite',
      );
      expect(pill.center.dy, lessThan(cell.top + 24));
    });

    testWidgets('sans agent connu : « génère » seul', (tester) async {
      await pumpBoard(tester);
      await create(tester, 'kpi');
      expect(tagText(tester, 'kpi').toLowerCase(), 'génère');
    });

    testWidgets('une nouvelle surface prend le cadre de la précédente', (
      tester,
    ) async {
      await pumpBoard(tester);
      await create(tester, 'kpi');
      expect(frame('kpi'), findsOneWidget);
      await create(tester, 'trend');
      expect(anyFrame(), findsOneWidget);
      expect(frame('trend'), findsOneWidget);
    });

    testWidgets('le cadre dure tout `components` et s\'achève à `data`', (
      tester,
    ) async {
      await pumpBoard(tester);
      await create(tester, 'kpi');
      await send(tester, <Object>[updateComponents('kpi', 'A')]);
      await tester.pump(const Duration(seconds: 5));
      expect(frame('kpi'), findsOneWidget, reason: 'toujours en génération');

      await send(tester, <Object>[updateDataModel('kpi', '/a', 'x')]);
      // Dernier tour puis fondu : encore là pendant le tour.
      await tester.pump(const Duration(seconds: 1));
      expect(frame('kpi'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      expect(frame('kpi'), findsNothing);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('une mutation de l\'acte 2 ne rouvre aucun cadre', (
      tester,
    ) async {
      await pumpBoard(tester);
      await create(tester, 'kpi');
      await send(tester, <Object>[updateComponents('kpi', 'A')]);
      expect(frame('kpi'), findsOneWidget);
      await send(tester, <Object>[updateDataModel('kpi', '/a', 'x')]);
      await tester.pump(const Duration(seconds: 5));
      expect(anyFrame(), findsNothing);

      await send(tester, <Object>[updateDataModel('kpi', '/a', 'y')]);
      await tester.pump(const Duration(seconds: 1));
      expect(anyFrame(), findsNothing);
      // Même si la page réaffirme la cible (même surface).
      generation.value = const GenerationTarget(surfaceId: 'kpi');
      await send(tester, <Object>[updateDataModel('kpi', '/a', 'z')]);
      expect(anyFrame(), findsNothing);
    });

    testWidgets('une surface restaurée (présente au premier rendu) n\'a pas '
        'de cadre', (tester) async {
      await pumpBoard(
        tester,
        before: <Object>[createSurface('kpi'), updateComponents('kpi', 'A')],
      );
      generation.value = const GenerationTarget(surfaceId: 'kpi');
      await tester.pump();
      expect(anyFrame(), findsNothing);
    });

    testWidgets('une surface déjà complète quand la cible arrive n\'a pas '
        'de cadre (rejeu positionné)', (tester) async {
      await pumpBoard(tester);
      await send(tester, <Object>[
        createSurface('kpi'),
        updateComponents('kpi', 'A'),
        updateDataModel('kpi', '/a', 'x'),
      ]);
      generation.value = const GenerationTarget(surfaceId: 'kpi');
      await tester.pump();
      expect(anyFrame(), findsNothing);
    });

    testWidgets('sous animations coupées : cadre statique, retiré sans fondu '
        'à `data`', (tester) async {
      await pumpBoard(tester, animations: false);
      await create(tester, 'kpi');
      expect(frame('kpi'), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
      await send(tester, <Object>[
        updateComponents('kpi', 'A'),
        updateDataModel('kpi', '/a', 'x'),
      ]);
      await tester.pump();
      expect(frame('kpi'), findsNothing);
    });

    testWidgets('le cadre est frère du contour de surbrillance, hors du '
        'ClipRect', (tester) async {
      await pumpBoard(tester);
      await create(tester, 'kpi');
      expect(
        find.ancestor(of: frame('kpi'), matching: find.byType(ClipRect)),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('surface-content-kpi')),
          matching: frame('kpi'),
        ),
        findsNothing,
      );
    });
    testWidgets('coexiste avec le contour pointillé de surbrillance : deux '
        'frères de la pile de la cellule, cadre dessous', (tester) async {
      await pumpBoard(tester);
      await create(tester, 'kpi');
      highlight.value = 'kpi';
      await tester.pump();

      final Finder outline = find.byKey(
        const ValueKey<String>('highlight-kpi'),
      );
      expect(outline, findsOneWidget);
      expect(frame('kpi'), findsOneWidget);

      final Stack stack = tester.widget<Stack>(
        find
            .descendant(
              of: find.byKey(const ValueKey<String>('surface-kpi')),
              matching: find.byType(Stack),
            )
            .first,
      );
      int indexOfDescendant(Finder finder) => stack.children.indexWhere(
        (Widget child) => tester.any(
          find.descendant(
            of: find.byWidget(child),
            matching: finder,
            matchRoot: true,
          ),
        ),
      );
      final int frameIndex = indexOfDescendant(frame('kpi'));
      final int outlineIndex = indexOfDescendant(outline);
      expect(frameIndex, isNonNegative);
      expect(outlineIndex, greaterThan(frameIndex));

      // La surbrillance s'éteint : le cadre reste.
      highlight.value = null;
      await tester.pump();
      expect(outline, findsNothing);
      expect(frame('kpi'), findsOneWidget);
    });
  });
}
