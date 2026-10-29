import 'dart:io';

import 'package:feature_agent_activity/feature_agent_activity.dart';
import 'package:feature_voice_session/feature_voice_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_canvas/app/config/genesis_config.dart';
import 'package:genesis_canvas/app/di/injection.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_backend_channel/shared_backend_channel.dart';
import 'package:shared_core/shared_core.dart';

void main() {
  // Port 1 : rien n'écoute ; toute connexion à la construction échouerait.
  final config = GenesisConfig.fromEnvironment(<String, String>{
    'GENESIS_BACKEND_URL': 'http://127.0.0.1:1',
  });

  GetIt build({
    GenesisConfig? withConfig,
    VoiceTransport Function()? voiceTransportFactory,
  }) {
    final getIt = GetIt.asNewInstance();
    configureDependencies(
      getIt,
      config: withConfig ?? config,
      voiceTransportFactory: voiceTransportFactory,
    );
    addTearDown(getIt.reset);
    return getIt;
  }

  test('l\'environnement du câblage réel s\'appelle live', () {
    expect(liveEnvironment.name, 'live');
  });

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
    expect(getIt<AppChannel>(), isA<WebSocketAppChannel>());
    expect(getIt<WebRtcPlatform>(), isA<FlutterWebRtcPlatform>());
    expect(getIt<VoiceTransport Function()>()(), isA<FlutterWebRtcTransport>());
    expect(getIt<EnvelopeLog Function()>()(), isA<EnvelopeLog>());
    final session = getIt<VoiceSession>();
    expect(getIt<LiveSessionEventSource>(), isNotNull);
    expect(getIt<VoiceSessionBloc>(), isNotNull);
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
    expect(getIt<AppChannel>(), same(getIt<AppChannel>()));
    expect(getIt<VoiceSession>(), isNot(same(getIt<VoiceSession>())));
    expect(getIt<VoiceSessionBloc>(), isNot(same(getIt<VoiceSessionBloc>())));
    expect(getIt<TranscriptBloc>(), isNot(same(getIt<TranscriptBloc>())));
    expect(getIt<AgentActivityBloc>(), isNot(same(getIt<AgentActivityBloc>())));
    expect(
      getIt<LiveSessionEventSource>(),
      isNot(same(getIt<LiveSessionEventSource>())),
    );
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
