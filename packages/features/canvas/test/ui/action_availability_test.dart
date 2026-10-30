import 'dart:async';

import 'package:a2ui_core/a2ui_core.dart' as a2ui;
import 'package:entity_catalog/entity_catalog.dart';
import 'package:feature_canvas/feature_canvas.dart';
import 'package:feature_canvas/src/ui/action_availability.dart'
    show ActionAvailability;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart' show Catalog, Surface, SurfaceController;
import 'package:shared_backend_channel/shared_backend_channel.dart';
import 'package:shared_design_system/shared_design_system.dart';

import '../support/catalog_harness.dart';

/// Faux client réseau : mémorise les actions reçues, répond 202.
class _RecordingClient implements CanvasActionClient {
  final List<String> actions = <String>[];

  @override
  Future<CanvasActionResult> send({
    required String action,
    required String surface,
  }) async {
    actions.add('$action@$surface');
    return CanvasActionResult.accepted;
  }
}

/// Disponibilité des actions de la Barre d'actions (T16) : lue par le
/// composant par un `InheritedWidget` interne à la slice.
void main() {
  late SurfaceController controller;

  Future<void> pumpBar(
    WidgetTester tester, {
    Widget Function(Widget)? wrap,
  }) async {
    controller = SurfaceController(catalogs: <Catalog>[genesisCatalog()]);
    addTearDown(controller.dispose);
    for (final Map<String, dynamic> json in contractFixture(
      'actions',
      GenesisContract.defaultCatalogId,
      variant: 'act2',
    )) {
      controller.handleMessage(a2ui.A2uiMessage.fromJson(json));
    }
    final Widget surface = SizedBox(
      width: 940,
      height: 200,
      child: Surface(surfaceContext: controller.contextFor('actions')),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          brightness: Brightness.dark,
          extensions: const <ThemeExtension<dynamic>>[SceneTheme.dark()],
        ),
        home: Scaffold(body: wrap == null ? surface : wrap(surface)),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  bool enabled(WidgetTester tester, String id) =>
      tester.widget<OutlinedButton>(find.byKey(Key('action-$id'))).enabled;

  testWidgets('sans fournisseur, les boutons sont inactifs', (tester) async {
    await pumpBar(tester);
    expect(enabled(tester, 'block_release'), isFalse);
    expect(enabled(tester, 'validate_release'), isFalse);
  });

  testWidgets('fournisseur désactivé : boutons inactifs, aucun appel', (
    tester,
  ) async {
    final calls = <String>[];
    await pumpBar(
      tester,
      wrap: (child) => ActionAvailability(
        enabled: false,
        onAction: (name, surface) => calls.add('$name@$surface'),
        child: child,
      ),
    );
    expect(enabled(tester, 'block_release'), isFalse);
    await tester.tap(find.byKey(const Key('action-block_release')));
    expect(calls, isEmpty);
  });

  testWidgets('fournisseur actif : le clic appelle onAction(nom, surface)', (
    tester,
  ) async {
    final calls = <String>[];
    await pumpBar(
      tester,
      wrap: (child) => ActionAvailability(
        enabled: true,
        onAction: (name, surface) => calls.add('$name@$surface'),
        child: child,
      ),
    );
    expect(enabled(tester, 'block_release'), isTrue);
    await tester.tap(find.byKey(const Key('action-validate_release')));
    expect(calls, <String>['validate_release@actions']);
  });

  testWidgets('CanvasActionScope : actif au repos, inactif pendant l action', (
    tester,
  ) async {
    final client = _RecordingClient();
    final bloc = CanvasActionBloc(
      client: client,
      settings: const CanvasActionSettings(
        retries: 0,
        retryInterval: Duration(milliseconds: 1),
        maxDuration: Duration(seconds: 30),
      ),
    );
    await pumpBar(
      tester,
      wrap: (child) => BlocProvider<CanvasActionBloc>.value(
        value: bloc,
        child: CanvasActionScope(enabled: true, child: child),
      ),
    );
    expect(enabled(tester, 'block_release'), isTrue);

    await tester.tap(find.byKey(const Key('action-block_release')));
    await tester.pump();
    await tester.pump();

    expect(client.actions, <String>['block_release@actions']);
    expect(enabled(tester, 'block_release'), isFalse);
    expect(enabled(tester, 'validate_release'), isFalse);

    bloc.add(const ActionActivityChanged(busy: true));
    bloc.add(const ActionActivityChanged(busy: false));
    await tester.pump();
    await tester.pump();
    expect(enabled(tester, 'block_release'), isTrue);
    // Le Bloc vit dans la zone du test : il se ferme en la faisant avancer.
    unawaited(bloc.close());
    await tester.pump();
  });

  testWidgets('CanvasActionScope désactivé (rejeu) : boutons inactifs', (
    tester,
  ) async {
    final bloc = CanvasActionBloc(
      client: _RecordingClient(),
      settings: const CanvasActionSettings(
        retries: 0,
        retryInterval: Duration(milliseconds: 1),
        maxDuration: Duration(seconds: 30),
      ),
    );
    await pumpBar(
      tester,
      wrap: (child) => BlocProvider<CanvasActionBloc>.value(
        value: bloc,
        child: CanvasActionScope(enabled: false, child: child),
      ),
    );
    expect(enabled(tester, 'block_release'), isFalse);
    // Le Bloc vit dans la zone du test : il se ferme en la faisant avancer.
    unawaited(bloc.close());
    await tester.pump();
  });
}
