import 'package:feature_voice_session/feature_voice_session.dart'
    show VoiceTransport;
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import '../config/genesis_config.dart';
import 'app_module.dart';
import 'injection.config.dart';

/// Environnement du câblage réel : c'est le seul graphe, il n'y a ni
/// environnement `test` ni faux dans `lib/`.
const Environment liveEnvironment = Environment('live');

/// Enregistre les dépendances dans l'instance de [GetIt] passée en paramètre
/// (aucune variable globale : l'injection se fait par constructeur, et
/// chaque app crée sa propre instance, sans état résiduel).
///
/// [config] est enregistrée AVANT l'`init` généré, dont les modules la
/// consomment. [voiceTransportFactory] est la seule substitution permise
/// (frontière plateforme, pour les tests) : elle tient lieu de fabrique de
/// transport du graphe (voir `registerFactoryFunctions`).
@InjectableInit(initializerName: 'init', asExtension: true)
void configureDependencies(
  GetIt getIt, {
  required GenesisConfig config,
  VoiceTransport Function()? voiceTransportFactory,
}) {
  getIt.registerSingleton<GenesisConfig>(config);
  getIt.init(environment: liveEnvironment.name);
  registerFactoryFunctions(getIt, voiceTransportFactory: voiceTransportFactory);
}
