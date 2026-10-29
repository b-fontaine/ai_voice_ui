import 'package:feature_agent_activity/feature_agent_activity.dart';
import 'package:feature_voice_session/feature_voice_session.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_backend_channel/shared_backend_channel.dart';
import 'package:shared_core/shared_core.dart';

import '../config/genesis_config.dart';

/// Câblage réel de la voix et du canal temps réel.
///
/// Les paquets ne dépendent pas d'`injectable` : tout est déclaré ici.
/// Rien n'effectue d'entrée-sortie à la construction (ni socket, ni fichier,
/// ni micro) : le réseau, le journal et le micro ne s'ouvrent qu'au `start`
/// de la session. Le `GenesisConfig` est enregistré par `configureDependencies`
/// avant l'`init`.
///
/// Écart : injectable ne sait pas enregistrer un type fonction (« is not a
/// class element »). Les deux fabriques `VoiceTransport Function()` et
/// `EnvelopeLog Function()` sont donc enregistrées à la main par
/// `registerFactoryFunctions`, juste après l'`init` généré.
/// Alias de `VoiceTransport Function()` (injectable exige un alias pour
/// résoudre un type fonction en paramètre ; le type exécuté est identique).
typedef VoiceTransportFactory = VoiceTransport Function();

/// Alias de `EnvelopeLog Function()` (voir [VoiceTransportFactory]).
typedef EnvelopeLogFactory = EnvelopeLog Function();

@module
abstract class AppModule {
  @lazySingleton
  AppClock clock() => SystemClock();

  @lazySingleton
  VoiceRelay voiceRelay(GenesisConfig config) => HttpVoiceRelay(
    baseUrl: config.backendUrl,
    createTimeout: config.relayCreateTimeout,
    deleteTimeout: config.relayDeleteTimeout,
  );

  @lazySingleton
  AppChannel appChannel(GenesisConfig config) =>
      WebSocketAppChannel(baseUrl: config.backendUrl);

  @lazySingleton
  WebRtcPlatform webRtcPlatform() => const FlutterWebRtcPlatform();

  // Factories : une nouvelle instance par résolution (la page résout une
  // fois ; ces objets portent l'état d'une page et sont fermés avec elle).
  //
  // `LiveSessionEventSource` et `VoiceSessionBloc` ne sont volontairement PAS
  // dans le graphe : résolus séparément, ils recevraient chacun leur propre
  // `VoiceSession`. La page (racine de composition) les construit avec
  // l'unique session qu'elle a résolue.

  @injectable
  VoiceSession voiceSession(
    VoiceTransportFactory transportFactory,
    VoiceRelay relay,
    AppChannel channel,
    EnvelopeLogFactory logFactory,
    GenesisConfig config,
  ) => VoiceSession(
    transportFactory: transportFactory,
    relay: relay,
    channel: channel,
    logFactory: logFactory,
    closeTimeout: config.sessionCloseTimeout,
  );

  @injectable
  TranscriptBloc transcriptBloc() => TranscriptBloc();

  @injectable
  AgentActivityBloc agentActivityBloc() => AgentActivityBloc();
}

/// Enregistre les fabriques (types fonction, hors portée d'injectable) :
/// chaque appel renvoie une NOUVELLE instance. [voiceTransportFactory], si
/// fournie, remplace la fabrique de transport du graphe (frontière
/// plateforme, pour les tests) : on ne la substitue donc qu'à
/// l'enregistrement, sans `allowReassignment`.
void registerFactoryFunctions(
  GetIt getIt, {
  VoiceTransport Function()? voiceTransportFactory,
}) {
  getIt.registerLazySingleton<VoiceTransport Function()>(
    () =>
        voiceTransportFactory ??
        () => FlutterWebRtcTransport(
          platform: getIt<WebRtcPlatform>(),
          iceTimeout: getIt<GenesisConfig>().iceTimeout,
        ),
  );
  getIt.registerLazySingleton<EnvelopeLog Function()>(() {
    final config = getIt<GenesisConfig>();
    final clock = getIt<AppClock>();
    return () =>
        EnvelopeLog(path: config.appLogPath, nowUnixMs: clock.nowUnixMs);
  });
}
