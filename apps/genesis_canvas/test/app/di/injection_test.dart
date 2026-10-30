import 'dart:io';

import 'package:feature_agent_activity/feature_agent_activity.dart';
import 'package:feature_voice_session/feature_voice_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_canvas/app/config/genesis_config.dart';
import 'package:genesis_canvas/app/di/injection.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_backend_channel/shared_backend_channel.dart';
import 'package:shared_core/shared_core.dart';
import 'package:testing_backend_fakes/testing_backend_fakes.dart';

void main() {
  // Port 1 : rien n'écoute ; toute connexion à la construction échouerait.
  final config = GenesisConfig.fromEnvironment(<String, String>{
    'GENESIS_BACKEND_URL': 'http://127.0.0.1:1',
  });

  GetIt build({
    GenesisConfig? withConfig,
    VoiceTransport Function()? voiceTransportFactory,
    StringSink? errorSink,
  }) {
    final getIt = GetIt.asNewInstance();
    configureDependencies(
      getIt,
      config: withConfig ?? config,
      errorSink: errorSink ?? StringBuffer(),
      voiceTransportFactory: voiceTransportFactory,
    );
    addTearDown(getIt.reset);
    return getIt;
  }

  test('résout tous les types sans entrée-sortie', () {
    final dir = Directory.systemTemp.createTempSync('genesis_di_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final logPath = '${dir.path}/sous/dossier/app.jsonl';
    final getIt = build(
      withConfig: GenesisConfig.fromEnvironment(<String, String>{
        'GENESIS_BACKEND_URL': 'http://127.0.0.1:1',
        'GENESIS_APP_LOG': logPath,
      }),
    );

    expect(getIt<GenesisConfig>().backendUrl.port, 1);
    expect(getIt<AppClock>(), isA<SystemClock>());
    expect(getIt<VoiceRelay>(), isA<HttpVoiceRelay>());
    expect(getIt<CanvasResetClient>(), isA<HttpCanvasResetClient>());
    expect(getIt<AppChannel>(), isA<WebSocketAppChannel>());
    expect(getIt<WebRtcPlatform>(), isA<FlutterWebRtcPlatform>());
    expect(getIt<VoiceTransport Function()>()(), isA<FlutterWebRtcTransport>());
    expect(getIt<EnvelopeLog Function()>()(), isA<EnvelopeLog>());
    final session = getIt<VoiceSession>();
    expect(getIt<TranscriptBloc>(), isNotNull);
    expect(getIt<AgentActivityBloc>(), isNotNull);
    expect(session, isNotNull);

    expect(Directory('${dir.path}/sous').existsSync(), isFalse);
  });

  test('config injectée : relais et canal pointent sur backendUrl', () {
    final getIt = build();

    expect((getIt<VoiceRelay>() as HttpVoiceRelay).baseUrl, config.backendUrl);
    expect(
      (getIt<AppChannel>() as WebSocketAppChannel).baseUrl,
      config.backendUrl,
    );
    expect(
      (getIt<VoiceRelay>() as HttpVoiceRelay).createTimeout,
      config.relayCreateTimeout,
    );
  });

  test('singletons paresseux partagés, factories à instance neuve', () {
    final getIt = build();

    expect(getIt<AppClock>(), same(getIt<AppClock>()));
    expect(getIt<VoiceRelay>(), same(getIt<VoiceRelay>()));
    expect(getIt<CanvasResetClient>(), same(getIt<CanvasResetClient>()));
    expect(getIt<AppChannel>(), same(getIt<AppChannel>()));
    expect(getIt<VoiceSession>(), isNot(same(getIt<VoiceSession>())));
    expect(getIt<TranscriptBloc>(), isNot(same(getIt<TranscriptBloc>())));
    expect(getIt<AgentActivityBloc>(), isNot(same(getIt<AgentActivityBloc>())));
  });

  test('la source et le Bloc de session sont construits par la page, '
      'pas par le graphe (une seule VoiceSession)', () {
    final getIt = build();

    expect(getIt.isRegistered<LiveSessionEventSource>(), isFalse);
    expect(getIt.isRegistered<VoiceSessionBloc>(), isFalse);
  });

  test('VoiceTransport Function() renvoie des transports distincts', () {
    final create = build()<VoiceTransport Function()>();

    expect(create(), isNot(same(create())));
  });

  test('EnvelopeLog inactif sans GENESIS_APP_LOG, nouveau à chaque appel', () {
    final create = build()<EnvelopeLog Function()>();

    expect(create().isActive, isFalse);
    expect(create(), isNot(same(create())));
  });

  test('voiceTransportFactory fournie remplace celle du graphe', () {
    var calls = 0;
    VoiceTransport substitute() {
      calls++;
      return FlutterWebRtcTransport(platform: const FlutterWebRtcPlatform());
    }

    final getIt = build(voiceTransportFactory: substitute);

    expect(getIt<VoiceTransport Function()>(), same(substitute));
    getIt<VoiceTransport Function()>()();
    expect(calls, 1);
  });

  test('le puits de diagnostic fourni est enregistré dans le graphe', () {
    final sink = StringBuffer();
    final getIt = build(errorSink: sink);

    expect(getIt<StringSink>(), same(sink));
  });

  test('délais du canal injectés depuis la configuration', () {
    final getIt = build(
      withConfig: const GenesisConfig(
        channelConnectTimeout: Duration(seconds: 3),
        channelCloseTimeout: Duration(seconds: 4),
      ),
    );

    final channel = getIt<AppChannel>() as WebSocketAppChannel;
    expect(channel.connectTimeout, const Duration(seconds: 3));
    expect(channel.closeTimeout, const Duration(seconds: 4));
  });

  test('reset ferme le relais : plus aucune requête ne part', () async {
    HttpOverrides.global = null;
    final backend = await FakeBackend.start();
    addTearDown(backend.close);
    final getIt = GetIt.asNewInstance();
    configureDependencies(
      getIt,
      config: GenesisConfig(backendUrl: Uri.parse(backend.url)),
      errorSink: StringBuffer(),
    );
    final relay = getIt<VoiceRelay>();
    await relay.deleteSession('sess-1').then<void>((_) {}, onError: (_) {});
    expect(backend.deletes, <String>['sess-1']);

    await getIt.reset();
    await relay.deleteSession('sess-2').then<void>((_) {}, onError: (_) {});

    expect(backend.deletes, <String>['sess-1']);
  });

  test('client de remise à vide : URL et délai injectés, aucune journalisation propre', () async {
    final sink = StringBuffer();
    final getIt = build(
      withConfig: GenesisConfig(
        backendUrl: Uri.parse('http://127.0.0.1:1'),
        canvasResetTimeout: const Duration(milliseconds: 700),
      ),
      errorSink: sink,
    );

    final client = getIt<CanvasResetClient>() as HttpCanvasResetClient;
    expect(client.baseUrl, Uri.parse('http://127.0.0.1:1'));
    expect(client.timeout, const Duration(milliseconds: 700));
    expect(await client.reset(), CanvasResetResult.unreachable);
    // La page consigne l'échec, une seule fois : le client reste muet.
    expect(sink.toString(), isEmpty);
  });

  test('reset ferme le client de remise à vide', () async {
    HttpOverrides.global = null;
    final backend = await FakeBackend.start();
    addTearDown(backend.close);
    final getIt = GetIt.asNewInstance();
    configureDependencies(
      getIt,
      config: GenesisConfig(backendUrl: Uri.parse(backend.url)),
      errorSink: StringBuffer(),
    );
    final client = getIt<CanvasResetClient>();
    expect(await client.reset(), CanvasResetResult.done);
    expect(backend.canvasResets, 1);

    await getIt.reset();

    expect(await client.reset(), CanvasResetResult.unreachable);
    expect(backend.canvasResets, 1);
  });

  test('deux GetIt.asNewInstance sont indépendants', () {
    final a = build();
    final b = build(
      withConfig: GenesisConfig.fromEnvironment(<String, String>{
        'GENESIS_BACKEND_URL': 'http://127.0.0.1:2',
      }),
    );

    expect(a<GenesisConfig>().backendUrl.port, 1);
    expect(b<GenesisConfig>().backendUrl.port, 2);
    expect(a<AppClock>(), isNot(same(b<AppClock>())));
  });
}
