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

const _catalog =
    'https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json';

/// `VoiceSession` réelle dont on observe `stop`/`dispose` et dont on pilote
/// les enveloppes (le canal réseau est la frontière : pas de socket ici).
class _ObservedSession extends VoiceSession {
  _ObservedSession(
    GetIt getIt,
    this.journal, {
    required super.closeTimeout,
    this.stopNeverEnds = false,
  }) : super(
         transportFactory: getIt<VoiceTransport Function()>(),
         relay: getIt<VoiceRelay>(),
         channel: getIt<AppChannel>(),
         logFactory: getIt<EnvelopeLog Function()>(),
       );

  final List<String> journal;
  final bool stopNeverEnds;
  final StreamController<AppChannelEnvelope> incoming =
      StreamController<AppChannelEnvelope>.broadcast();
  bool _disposing = false;
  int stopCalls = 0;

  @override
  Stream<AppChannelEnvelope> get envelopes => incoming.stream;

  @override
  Future<void> stop() {
    if (!_disposing) {
      stopCalls++;
      journal.add('session.stop');
    }
    if (stopNeverEnds && !_disposing) return Completer<void>().future;
    return super.stop();
  }

  @override
  Future<void> dispose() {
    _disposing = true;
    journal.add('session.dispose');
    return super.dispose();
  }

  void receive(Map<String, Object?> a2uiMessage) => incoming.add(
    AppChannelEnvelope(
      version: 1,
      type: AppChannelTypes.a2ui,
      session: 's1',
      tMs: 0,
      data: a2uiMessage,
    ),
  );
}

class _Rig {
  _Rig(WidgetTester tester, {GenesisConfig? config, bool stopNeverEnds = false})
    : getIt = GetIt.asNewInstance() {
    configureDependencies(
      getIt,
      config: config ?? const GenesisConfig(),
      errorSink: errors,
    );
    settings = pageSettingsOf(config ?? const GenesisConfig());
    final closeTimeout = (config ?? const GenesisConfig()).sessionCloseTimeout;
    session = _ObservedSession(
      getIt,
      journal,
      closeTimeout: closeTimeout,
      stopNeverEnds: stopNeverEnds,
    );
    getIt.unregister<VoiceSession>();
    getIt.registerFactory<VoiceSession>(() {
      resolved++;
      return session;
    });
    addTearDown(() async {
      await session.incoming.close();
      await getIt.reset();
    });
  }

  final GetIt getIt;
  late final GenesisCanvasPageSettings settings;
  final List<String> journal = <String>[];
  late final _ObservedSession session;
  int resolved = 0;
  final StringBuffer errors = StringBuffer();

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
  for (var i = 0; i < 5; i++) {
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

    expect(rig.resolved, 1);
  });

  testWidgets('ordre de fermeture : Bloc de session, stop, dispose, source, '
      'puis les autres Blocs', (tester) async {
    final rig = _Rig(tester);
    await rig.mount(tester);
    final journal = rig.journal;
    final ctx = rig.context;
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

    expect(journal, <String>[
      'bloc.session closed',
      'session.stop',
      'session.dispose',
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

    await tester.pumpWidget(const SizedBox());
    await drain(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(rig.journal, <String>['session.stop']);

    await tester.pump(const Duration(seconds: 1));
    await drain(tester);
    expect(rig.journal, contains('session.dispose'));
    expect(rig.errors.toString(), contains('arrêt de la session a échoué'));
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

    AppExitResponse? response;
    unawaited(
      tester.binding.handleRequestAppExit().then((value) => response = value),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(rig.session.stopCalls, 1);
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

      rig.session.receive(create());
      rig.session.receive(text());
      await tester.pump();
      await tester.pump();

      expect(find.text('vivant'), findsOneWidget);
      expect(startEnabled(tester), isTrue);
    });

    testWidgets('avec scénario : la source vivante n\'est pas branchée au '
        'canevas et Démarrer est désactivé', (tester) async {
      final rig = _Rig(tester);
      final replay = StreamController<A2uiMessage>();
      addTearDown(replay.close);
      await rig.mount(tester, replay: replay.stream);

      rig.session.receive(create());
      rig.session.receive(text());
      await tester.pump();
      await tester.pump();

      expect(find.text('vivant'), findsNothing);
      expect(startEnabled(tester), isFalse);
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
