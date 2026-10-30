import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:feature_agent_activity/feature_agent_activity.dart';
import 'package:feature_canvas/feature_canvas.dart';
import 'package:feature_voice_session/feature_voice_session.dart';
import 'package:flutter/material.dart' show FilledButton;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/page_settings.dart';

import 'package:genesis_canvas/pages/genesis_canvas/genesis_canvas_page_settings.dart';
import 'package:genesis_canvas/app/bootstrap/snapshot_service.dart';
import 'package:genesis_canvas/app/config/genesis_config.dart';
import 'package:genesis_canvas/app/di/injection.dart';
import 'package:genesis_canvas/pages/genesis_canvas/genesis_canvas.dart';
import 'package:genesis_canvas/widgets/top_bar/top_bar.dart';
import 'package:genui/genui.dart' show BasicCatalogItems, Catalog;
import 'package:get_it/get_it.dart';
import 'package:a2ui_core/a2ui_core.dart' show A2uiMessage;
import 'package:shared_backend_channel/shared_backend_channel.dart';
import 'package:testing_voice_fakes/testing_voice_fakes.dart';

const _catalog =
    'https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json';

/// Banc : la page, la vraie `VoiceSession` (et son `VoiceSessionBloc`) sur les
/// faux de frontière (transport WebRTC, relais, canal). Les enveloppes sont
/// poussées par le faux canal ; la fermeture s'observe par le journal des
/// faux (`relay.delete`, `t1.stop`, `t1.dispose`) et par la fin du flux
/// `status` de la session.
class _Rig {
  _Rig(WidgetTester tester, {GenesisConfig? config, bool stopNeverEnds = false})
    : getIt = GetIt.asNewInstance() {
    final cfg = config ?? const GenesisConfig();
    configureDependencies(getIt, config: cfg, errorSink: errors);
    settings = pageSettingsOf(cfg);
    harness = VoiceHarness(closeTimeout: cfg.sessionCloseTimeout);
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
  int resolved = 0;
  final StringBuffer errors = StringBuffer();

  /// Journal commun des faux (relais, canal, transport) et des observateurs
  /// que les tests y ajoutent.
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

  Future<void> mount(WidgetTester tester, {Stream<A2uiMessage>? replay}) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: GenesisCanvasPage(
          getIt: getIt,
          catalogs: <Catalog>[BasicCatalogItems.asCatalog()],
          replay: replay,
          snapshotFactory: (exitHandler) => SnapshotService(
            path: null,
            exitHandler: exitHandler,
            errorSink: errors,
          ),
          exitHandler: (_) {},
          errorSink: errors,
          settings: settings,
        ),
      ),
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

void main() {
  testWidgets('la page ne résout qu\'une VoiceSession, partagée', (
    tester,
  ) async {
    final rig = _Rig(tester);
    await rig.mount(tester);
    await rig.start(tester);

    expect(rig.resolved, 1);
  });

  testWidgets('ordre de fermeture : Bloc de session, stop, dispose, source, '
      'puis les autres Blocs', (tester) async {
    final rig = _Rig(tester);
    await rig.mount(tester);
    await rig.start(tester);
    final journal = rig.journal;
    final ctx = rig.context;
    rig.harness.session.status.listen(
      null,
      onDone: () => journal.add('session.status done'),
    );
    ctx.read<VoiceSessionBloc>().stream.listen(
      null,
      onDone: () => journal.add('bloc.session closed'),
    );
    ctx.read<TranscriptBloc>().stream.listen(
      null,
      onDone: () => journal.add('bloc.transcript closed'),
    );
    ctx.read<AgentActivityBloc>().stream.listen(
      null,
      onDone: () => journal.add('bloc.agents closed'),
    );
    ctx.read<CanvasBloc>().stream.listen((state) {
      if (state.sourceStatus == CanvasSourceStatus.completed) {
        journal.add('source disposed');
      }
    }, onDone: () => journal.add('bloc.canvas closed'));

    await tester.pumpWidget(const SizedBox());
    await drain(tester);

    // La fin du flux `status` (libération de la session) est notifiée de façon
    // asynchrone : on la situe entre la libération du transport et la fermeture
    // du Bloc de transcription, sans l'ordonner finement par rapport à la
    // source (que la page ne ferme qu'après l'avoir attendue).
    final statusDone = journal.indexOf('session.status done');
    expect(statusDone, greaterThan(journal.indexOf('t1.dispose')));
    expect(statusDone, lessThan(journal.indexOf('bloc.transcript closed')));
    journal.remove('session.status done');
    expect(journal, <String>[
      'bloc.session closed',
      'relay.delete(s1)',
      't1.stop',
      't1.dispose',
      'source disposed',
      'bloc.transcript closed',
      'bloc.agents closed',
      'bloc.canvas closed',
    ]);
    expect(rig.errors.toString(), isEmpty);
  });

  testWidgets('stop qui ne se termine pas : borné par sessionCloseTimeout, '
      'la fermeture continue', (tester) async {
    final rig = _Rig(
      tester,
      config: const GenesisConfig(sessionCloseTimeout: Duration(seconds: 3)),
      stopNeverEnds: true,
    );
    await rig.mount(tester);
    await rig.start(tester);
    rig.context.read<CanvasBloc>().stream.listen(
      null,
      onDone: () => rig.journal.add('bloc.canvas closed'),
    );

    await tester.pumpWidget(const SizedBox());
    await drain(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(rig.journal, <String>['relay.delete(s1)', 't1.stop']);
    expect(rig.errors.toString(), isEmpty);

    await tester.pump(const Duration(seconds: 1));
    await drain(tester);
    expect(rig.errors.toString(), contains('arrêt de la session a échoué'));

    // La libération, bornée à son tour, échoue sans bloquer la suite.
    await tester.pump(const Duration(seconds: 3));
    await drain(tester);
    expect(
      rig.errors.toString(),
      contains('libération de la session a échoué'),
    );
    expect(rig.journal, contains('bloc.canvas closed'));
  });

  testWidgets('sortie de l\'app : stop attendu, borné par exitCloseTimeout', (
    tester,
  ) async {
    final rig = _Rig(
      tester,
      config: const GenesisConfig(exitCloseTimeout: Duration(seconds: 2)),
      stopNeverEnds: true,
    );
    await rig.mount(tester);
    await rig.start(tester);

    AppExitResponse? response;
    unawaited(
      tester.binding.handleRequestAppExit().then((value) => response = value),
    );
    await drain(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(rig.journal, <String>['relay.delete(s1)', 't1.stop']);
    expect(response, isNull);

    await tester.pump(const Duration(seconds: 1));
    expect(response, AppExitResponse.exit);
  });

  group('source vivante et mode scénario', () {
    Map<String, Object?> create() => <String, Object?>{
      'version': 'v0.9',
      'createSurface': <String, Object?>{
        'surfaceId': 's',
        'catalogId': _catalog,
      },
    };
    Map<String, Object?> text() => <String, Object?>{
      'version': 'v0.9',
      'updateComponents': <String, Object?>{
        'surfaceId': 's',
        'components': <Object?>[
          <String, Object?>{
            'id': 'root',
            'component': 'Text',
            'text': 'vivant',
          },
        ],
      },
    };

    bool startEnabled(WidgetTester tester) =>
        tester
            .widget<FilledButton>(find.byKey(const Key('start-button')))
            .onPressed !=
        null;

    testWidgets('sans scénario : les a2ui de la source vivante vont au '
        'canevas et Démarrer est actif', (tester) async {
      final rig = _Rig(tester);
      await rig.mount(tester);
      expect(startEnabled(tester), isTrue);
      await rig.start(tester);

      rig.receive(create());
      rig.receive(text());
      await tester.pump();
      await tester.pump();

      expect(find.text('vivant'), findsOneWidget);
    });

    testWidgets('avec scénario : la source vivante n\'est pas branchée au '
        'canevas et Démarrer est désactivé', (tester) async {
      final rig = _Rig(tester);
      final replay = StreamController<A2uiMessage>();
      addTearDown(replay.close);
      await rig.mount(tester, replay: replay.stream);
      expect(startEnabled(tester), isFalse);
      await rig.start(tester);

      rig.receive(create());
      rig.receive(text());
      await tester.pump();
      await tester.pump();

      expect(find.text('vivant'), findsNothing);
      expect(rig.errors.toString(), isEmpty);
    });

    testWidgets('sans scénario, la fin de la source ne dit pas '
        '« Rejeu impossible »', (tester) async {
      final rig = _Rig(tester);
      await rig.mount(tester);

      await tester.pumpWidget(const SizedBox());
      await drain(tester);

      expect(rig.errors.toString(), isNot(contains('Rejeu impossible')));
    });
  });
}
