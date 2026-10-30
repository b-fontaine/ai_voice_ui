import 'dart:async';
import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart' show A2uiMessage;
import 'package:feature_canvas/feature_canvas.dart';
import 'package:feature_voice_session/feature_voice_session.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_canvas/app/bootstrap/snapshot_service.dart';
import 'package:genesis_canvas/app/config/genesis_config.dart';
import 'package:genesis_canvas/app/di/injection.dart';
import 'package:genesis_canvas/app/theme/genesis_theme.dart';
import 'package:genesis_canvas/pages/genesis_canvas/genesis_canvas.dart';
import 'package:genesis_canvas/pages/genesis_canvas/genesis_canvas_page_settings.dart';
import 'package:genesis_canvas/widgets/top_bar/top_bar.dart';
import 'package:entity_catalog/entity_catalog.dart' show GenesisContract;
import 'package:flutter/material.dart' show Material, MaterialApp, MaterialType;
import 'package:genui/genui.dart' show Catalog;
import 'package:get_it/get_it.dart';
import 'package:shared_backend_channel/shared_backend_channel.dart';
import 'package:testing_backend_fakes/testing_backend_fakes.dart';
import 'package:testing_voice_fakes/testing_voice_fakes.dart';

import 'page_settings.dart';

const rigCatalog = GenesisContract.defaultCatalogId;

/// Faux client de remise à vide du backend (frontière réseau) : il consigne
/// l'appel dans le journal commun des faux.
class FakeResetClient implements CanvasResetClient {
  FakeResetClient(this.journal);

  final List<String> journal;
  CanvasResetResult result = CanvasResetResult.done;

  /// Résultats rendus dans l'ordre, un par appel ; vide : [result].
  final List<CanvasResetResult> script = <CanvasResetResult>[];
  int calls = 0;

  @override
  Future<CanvasResetResult> reset() {
    calls++;
    journal.add('client.reset');
    return Future<CanvasResetResult>.value(
      script.isEmpty ? result : script.removeAt(0),
    );
  }
}

/// Banc : la page, la vraie `VoiceSession` (et son `VoiceSessionBloc`) sur les
/// faux de frontière (transport WebRTC, relais, canal, client de remise à
/// vide). Les enveloppes sont poussées par le faux canal ; la fermeture
/// s'observe par le journal des faux (`relay.delete`, `t1.stop`, `t1.dispose`)
/// et par la fin du flux `status` de la session.
class PageRig {
  PageRig(
    WidgetTester tester, {
    GenesisConfig? config,
    bool stopNeverEnds = false,
  }) : getIt = GetIt.asNewInstance() {
    final cfg = config ?? const GenesisConfig();
    configureDependencies(getIt, config: cfg, errorSink: errors);
    settings = pageSettingsOf(cfg);
    harness = VoiceHarness(closeTimeout: cfg.sessionCloseTimeout);
    resetClient = FakeResetClient(harness.events);
    if (stopNeverEnds) {
      // Le transport ne rend jamais la main sur `stop` (frontière WebRTC).
      harness.onNewTransport = (transport) =>
          transport.stopHook = () => Completer<void>().future;
    }
    getIt.unregister<VoiceSession>();
    getIt.registerFactory<VoiceSession>(() {
      resolved++;
      return harness.session;
    });
    getIt.unregister<CanvasResetClient>();
    getIt.registerSingleton<CanvasResetClient>(resetClient);
    addTearDown(() async {
      for (final controller in harness.channel.controllers) {
        await controller.close();
      }
      await getIt.reset();
    });
  }

  final GetIt getIt;
  late final GenesisCanvasPageSettings settings;
  late final VoiceHarness harness;
  late final FakeResetClient resetClient;
  int resolved = 0;
  final StringBuffer errors = StringBuffer();

  /// Journal commun des faux (relais, canal, transport, client de remise à
  /// vide) et des observateurs que les tests y ajoutent.
  List<String> get journal => harness.events;

  /// Démarre la session par les frontières (le bouton Démarrer est inactif en
  /// mode scénario) puis vide le journal : seule la suite est observée.
  Future<void> start(WidgetTester tester) async {
    unawaited(harness.session.start());
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    expect(harness.session.current, isA<Active>());
    journal.clear();
  }

  /// Pousse un message A2UI par le faux canal WSS.
  void receive(Map<String, Object?> a2uiMessage) =>
      harness.channel.emit(envelopeOf(AppChannelTypes.a2ui, a2uiMessage));

  /// Pousse une enveloppe du backend (`plan`, `agent.activity`, `a2ui`…) sous
  /// sa forme JSON, comme le fait le faux backend.
  void receiveEnvelope(Map<String, Object?> envelope) =>
      harness.channel.emit(AppChannelEnvelope.parse(jsonEncode(envelope)));

  /// Monte la page à la taille de l'écran de la démo. [themed] : sous le
  /// `MaterialApp` et le thème de l'app (SceneTheme installé), comme en prod.
  Future<void> mount(
    WidgetTester tester, {
    Stream<A2uiMessage>? replay,
    Size size = const Size(1920, 1080),
    bool themed = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final page = GenesisCanvasPage(
      getIt: getIt,
      catalogs: <Catalog>[genesisCatalog(catalogId: rigCatalog)],
      catalogId: rigCatalog,
      replay: replay,
      snapshotFactory: (exitHandler) => SnapshotService(
        path: null,
        exitHandler: exitHandler,
        errorSink: errors,
      ),
      exitHandler: (_) {},
      errorSink: errors,
      settings: settings,
    );
    await tester.pumpWidget(
      themed
          ? MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: genesisThemeData(),
              home: Material(type: MaterialType.transparency, child: page),
            )
          : Directionality(textDirection: TextDirection.ltr, child: page),
    );
    // Bornés : l'orbe au repos pulse sans fin (jamais `pumpAndSettle`).
    await tester.pump(const Duration(milliseconds: 50));
  }

  BuildContext get context => find.byType(TopBar).evaluate().first;
}

/// Laisse la chaîne de fermeture avancer : la fermeture d'un Bloc dont un
/// `emit.forEach` est en cours demande un tour de la boucle d'événements
/// RÉELLE, que `pump` seul (zone FakeAsync) ne donne pas.
Future<void> drain(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
}

/// Les enveloppes de l'acte 1 du contrat, telles que le backend les émet :
/// `plan`, activité au travail, douze messages `a2ui` (quatre surfaces en
/// trois temps, avec agent et tâche), activité terminée. Lues dans
/// `contracts/a2ui/genesis/v1/examples` (E/S réelle, hors zone FakeAsync).
Future<List<Map<String, Object?>>> act1Envelopes(WidgetTester tester) async {
  final surfaces = (await tester.runAsync(
    () => ContractFixtures.act1Surfaces(catalogId: rigCatalog),
  ))!;
  Map<String, Object?> envelope(
    String type,
    Map<String, Object?> data, {
    String? agent,
    String? task,
  }) => <String, Object?>{
    'v': 1,
    'type': type,
    'session': 's1',
    't_ms': 10,
    'data': data,
    'agent': ?agent,
    'task': ?task,
  };
  Map<String, Object?> activity(Act1Surface s, String state) => envelope(
    'agent.activity',
    <String, Object?>{
      'agent': s.agent,
      'task': s.task,
      'state': state,
      'label': s.agent,
    },
    agent: s.agent,
    task: s.task,
  );
  final seen = <String>{};
  final distinct = [
    for (final s in surfaces)
      if (seen.add(s.agent)) s,
  ];
  return <Map<String, Object?>>[
    envelope('plan', <String, Object?>{
      'delegation': 'deleg_1',
      'selected': ContractFixtures.act1Agents,
      'idle': <String>[],
    }),
    for (final s in distinct) activity(s, 'working'),
    for (final s in surfaces)
      for (final message in s.messages)
        envelope('a2ui', message, agent: s.agent, task: s.task),
    for (final s in distinct) activity(s, 'completed'),
  ];
}
