import 'package:a2ui_core/a2ui_core.dart' as a2ui;
import 'package:entity_catalog/entity_catalog.dart';
import 'package:feature_canvas/feature_canvas.dart';
import 'package:feature_canvas/src/ui/action_availability.dart'
    show ActionAvailability;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart' show Catalog, Surface, SurfaceController;
import 'package:shared_design_system/shared_design_system.dart';

import '../support/catalog_harness.dart';

/// Rendu complet de `ActionBar` (T15) : tons, trois états de la slice, clic,
/// lisibilité et tenue dans le bandeau de 72 px.
void main() {
  const SceneTheme theme = SceneTheme.dark();
  late SurfaceController controller;

  Widget app(Widget child) => MaterialApp(
    theme: ThemeData(
      brightness: Brightness.dark,
      extensions: const <ThemeExtension<dynamic>>[SceneTheme.dark()],
    ),
    home: Scaffold(body: child),
  );

  void feed(
    Map<String, dynamic> Function(Map<String, dynamic> value)? alter, {
    bool withData = true,
  }) {
    for (final Map<String, dynamic> json in contractFixture(
      'actions',
      GenesisContract.defaultCatalogId,
      variant: 'act2',
    )) {
      if (json.containsKey('updateDataModel')) {
        if (!withData) continue;
        final body = json['updateDataModel'] as Map<String, dynamic>;
        if (alter != null) {
          body['value'] = alter(
            cloneJson(body['value'] as Map<String, dynamic>),
          );
        }
      }
      controller.handleMessage(a2ui.A2uiMessage.fromJson(json));
    }
  }

  Future<void> pumpBar(
    WidgetTester tester, {
    Map<String, dynamic> Function(Map<String, dynamic> value)? alter,
    bool withData = true,
    void Function(String name, String surfaceId)? onAction,
    bool enabled = true,
    double height = CanvasBoard.actionsBandHeight,
  }) async {
    controller = SurfaceController(catalogs: <Catalog>[genesisCatalog()]);
    addTearDown(controller.dispose);
    feed(alter, withData: withData);
    Widget surface = Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        key: const Key('band'),
        width: 940,
        height: height,
        child: Surface(surfaceContext: controller.contextFor('actions')),
      ),
    );
    if (onAction != null) {
      surface = ActionAvailability(
        enabled: enabled,
        onAction: onAction,
        child: surface,
      );
    }
    await tester.pumpWidget(app(surface));
    await tester.pump();
    await tester.pump();
  }

  OutlinedButton button(WidgetTester tester, String id) =>
      tester.widget<OutlinedButton>(find.byKey(Key('action-$id')));

  Color foreground(OutlinedButton b, Set<WidgetState> states) =>
      b.style!.foregroundColor!.resolve(states)!;

  Color border(OutlinedButton b, Set<WidgetState> states) =>
      b.style!.side!.resolve(states)!.color;

  group('couleur par ton, jamais par libellé (RG-09)', () {
    testWidgets('bouton actif : danger et neutral ont leurs jetons', (
      tester,
    ) async {
      await pumpBar(tester, onAction: (_, _) {});
      final OutlinedButton danger = button(tester, 'block_release');
      final OutlinedButton neutral = button(tester, 'validate_release');
      expect(foreground(danger, <WidgetState>{}), theme.blockingForeground);
      expect(border(danger, <WidgetState>{}), theme.actionDangerBorder);
      expect(foreground(neutral, <WidgetState>{}), theme.textPrimary);
      expect(border(neutral, <WidgetState>{}), theme.actionNeutralBorder);
    });

    testWidgets('le texte peint reprend la couleur du ton', (tester) async {
      await pumpBar(tester, onAction: (_, _) {});
      expect(
        tester.widget<Text>(find.text('Bloquer la release')).style!.color,
        theme.blockingForeground,
      );
      expect(
        tester.widget<Text>(find.text('Valider la release')).style!.color,
        theme.textPrimary,
      );
    });

    testWidgets('bouton inactif : mêmes jetons, texte lisible', (tester) async {
      await pumpBar(tester);
      final OutlinedButton danger = button(tester, 'block_release');
      final OutlinedButton neutral = button(tester, 'validate_release');
      const Set<WidgetState> off = <WidgetState>{WidgetState.disabled};
      expect(danger.enabled, isFalse);
      expect(foreground(danger, off), theme.blockingForeground);
      expect(border(danger, off), theme.actionDangerBorder);
      expect(foreground(neutral, off), theme.textPrimary);
      expect(border(neutral, off), theme.actionNeutralBorder);
    });

    testWidgets('les tons permutés, la couleur suit le ton et non le libellé', (
      tester,
    ) async {
      await pumpBar(
        tester,
        onAction: (_, _) {},
        alter: (v) {
          final List<dynamic> actions = v['actions'] as List<dynamic>;
          (actions[0] as Map<String, dynamic>)['tone'] = 'neutral';
          (actions[1] as Map<String, dynamic>)['tone'] = 'danger';
          return v;
        },
      );
      expect(
        foreground(button(tester, 'block_release'), <WidgetState>{}),
        theme.textPrimary,
      );
      expect(
        foreground(button(tester, 'validate_release'), <WidgetState>{}),
        theme.blockingForeground,
      );
      expect(
        border(button(tester, 'validate_release'), <WidgetState>{}),
        theme.actionDangerBorder,
      );
    });
  });

  group('clic', () {
    testWidgets('un bouton actif appelle onAction(id, actions)', (
      tester,
    ) async {
      final List<String> calls = <String>[];
      await pumpBar(
        tester,
        onAction: (name, surface) => calls.add('$name@$surface'),
      );
      await tester.tap(find.byKey(const Key('action-block_release')));
      expect(calls, <String>['block_release@actions']);
    });

    testWidgets('sans fournisseur : onPressed nul, aucun appel', (
      tester,
    ) async {
      await pumpBar(tester);
      expect(button(tester, 'block_release').onPressed, isNull);
      expect(button(tester, 'validate_release').onPressed, isNull);
    });

    testWidgets('enabled: false : onPressed nul, aucun appel', (tester) async {
      final List<String> calls = <String>[];
      await pumpBar(
        tester,
        enabled: false,
        onAction: (name, surface) => calls.add(name),
      );
      expect(button(tester, 'validate_release').onPressed, isNull);
      await tester.tap(
        find.byKey(const Key('action-validate_release')),
        warnIfMissed: false,
      );
      expect(calls, isEmpty);
    });
  });

  group('trois états de la slice', () {
    testWidgets('squelette peint par CanvasBoard dès createSurface', (
      tester,
    ) async {
      controller = SurfaceController(catalogs: <Catalog>[genesisCatalog()]);
      final CanvasBloc bloc = CanvasBloc(controller);
      addTearDown(() async {
        await bloc.close();
        controller.dispose();
      });
      await tester.pumpWidget(
        app(
          BlocProvider<CanvasBloc>.value(
            value: bloc,
            child: SizedBox(
              width: 940,
              height: 600 + CanvasBoard.actionsBandHeight,
              child: CanvasBoard(controller: controller),
            ),
          ),
        ),
      );
      final Map<String, dynamic> create = contractFixture(
        'actions',
        GenesisContract.defaultCatalogId,
        variant: 'act2',
      ).first;
      bloc.add(A2uiMessageReceived(a2ui.A2uiMessage.fromJson(create)));
      for (var i = 0; i < 6; i++) {
        await tester.pump();
      }
      expect(find.byKey(const Key('skeleton-actions')), findsOneWidget);
      expect(find.byType(OutlinedButton), findsNothing);
    });

    testWidgets('sans données : cellule nodata-actions', (tester) async {
      await pumpBar(tester, withData: false);
      expect(find.byKey(const Key('nodata-actions')), findsOneWidget);
      expect(find.byKey(const Key('neutral-actions')), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
    });

    final Map<String, Map<String, dynamic> Function(Map<String, dynamic>)>
    invalid = <String, Map<String, dynamic> Function(Map<String, dynamic>)>{
      'action incomplète (sans tone)': (v) {
        ((v['actions'] as List)[0] as Map).remove('tone');
        return v;
      },
      'id hors actionIds': (v) {
        ((v['actions'] as List)[1] as Map)['id'] = 'ship_it';
        return v;
      },
      'tone hors actionTones': (v) {
        ((v['actions'] as List)[0] as Map)['tone'] = 'primary';
        return v;
      },
      'actions absent': (v) => v..remove('actions'),
    };
    for (final entry in invalid.entries) {
      testWidgets('${entry.key} : état neutre sans bouton', (tester) async {
        await pumpBar(tester, onAction: (_, _) {}, alter: entry.value);
        expect(find.byKey(const Key('neutral-actions')), findsOneWidget);
        expect(find.byKey(const Key('nodata-actions')), findsNothing);
        expect(find.byType(OutlinedButton), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('lisibilité et bandeau de 72 px', () {
    testWidgets('textes >= 24 px, cibles >= 48 px, sans débordement', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(940, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // Libellés courts : la police de test (Ahem) est bien plus large que
      // la police réelle, et la ligne doit tenir dans 940 px.
      await pumpBar(
        tester,
        onAction: (_, _) {},
        alter: (v) {
          final List<dynamic> actions = v['actions'] as List<dynamic>;
          (actions[0] as Map<String, dynamic>)['label'] = 'Geler';
          (actions[1] as Map<String, dynamic>)['label'] = 'Valider';
          return v;
        },
      );
      expect(tester.takeException(), isNull);
      for (final String label in <String>['Décision', 'Geler', 'Valider']) {
        final Text text = tester.widget<Text>(find.text(label));
        expect(text.style!.fontSize, greaterThanOrEqualTo(24), reason: label);
      }
      for (final String id in <String>['block_release', 'validate_release']) {
        final Size size = tester.getSize(find.byKey(Key('action-$id')));
        expect(size.height, greaterThanOrEqualTo(48), reason: id);
        expect(size.width, greaterThanOrEqualTo(48), reason: id);
      }
      final Rect frame = tester.getRect(find.byKey(const Key('band')));
      expect(frame.height, CanvasBoard.actionsBandHeight);
      for (final String id in <String>['block_release', 'validate_release']) {
        final Rect r = tester.getRect(find.byKey(Key('action-$id')));
        expect(r.top, greaterThanOrEqualTo(frame.top));
        expect(frame.width, 940);
        // Marges verticales égales : le bouton de 48 px est centré dans 72 px.
        expect(r.top - frame.top, frame.bottom - r.bottom, reason: id);
        expect(r.bottom, lessThanOrEqualTo(frame.bottom));
        expect(r.right, lessThanOrEqualTo(frame.right));
      }
    });
  });

  group('libellé très long dans le bandeau de 72 px', () {
    testWidgets('120 caractères : aucun débordement, cible >= 48 px, '
        'texte >= 24 px', (tester) async {
      tester.view.physicalSize = const Size(940, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpBar(
        tester,
        onAction: (_, _) {},
        alter: (v) {
          final List<dynamic> actions = v['actions'] as List<dynamic>;
          (actions[0] as Map<String, dynamic>)['label'] = 'L' * 120;
          return v;
        },
      );
      expect(tester.takeException(), isNull);
      final Rect frame = tester.getRect(find.byKey(const Key('band')));
      expect(frame.height, 72);
      expect(frame.width, 940);
      final Finder long = find.byKey(const Key('action-block_release'));
      final Rect r = tester.getRect(long);
      expect(r.height, greaterThanOrEqualTo(48));
      expect(r.top, greaterThanOrEqualTo(frame.top));
      expect(r.bottom, lessThanOrEqualTo(frame.bottom));
      expect(r.right, lessThanOrEqualTo(frame.right));
      final Text text = tester.widget<Text>(
        find.descendant(of: long, matching: find.byType(Text)),
      );
      expect(text.style!.fontSize, greaterThanOrEqualTo(24));
    });
  });

  group('libellés issus de la donnée', () {
    testWidgets('un libellé inventé et un titre inventé sont affichés tels '
        'quels', (tester) async {
      await pumpBar(
        tester,
        onAction: (_, _) {},
        alter: (v) {
          v['title'] = 'Choix de la salle';
          final List<dynamic> actions = v['actions'] as List<dynamic>;
          (actions[0] as Map<String, dynamic>)['label'] = 'Geler la sortie';
          (actions[1] as Map<String, dynamic>)['label'] = 'Go pour demain';
          return v;
        },
      );
      expect(find.text('Choix de la salle'), findsOneWidget);
      expect(find.text('Geler la sortie'), findsOneWidget);
      expect(find.text('Go pour demain'), findsOneWidget);
      expect(find.text('Bloquer la release'), findsNothing);
      expect(find.text('Valider la release'), findsNothing);
    });
  });
}
