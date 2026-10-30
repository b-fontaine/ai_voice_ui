import 'package:feature_voice_session/feature_voice_session.dart'
    show VoiceTransport;
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import '../config/genesis_config.dart';
import 'app_module.dart';
import 'injection.config.dart';

/// Enregistre les dépendances dans l'instance de [GetIt] passée en paramètre
/// (aucune variable globale : l'injection se fait par constructeur, et
/// chaque app crée sa propre instance, sans état résiduel).
///
/// [config] est enregistrée AVANT l'`init` généré, dont les modules la
/// consomment. [voiceTransportFactory] est la seule substitution permise
/// (frontière plateforme, pour les tests) : elle tient lieu de fabrique de
/// transport du graphe (voir `registerFactoryFunctions`). [errorSink] reçoit
/// les diagnostics (phrases fermées) et est enregistré dans le graphe.
@InjectableInit(initializerName: 'init', asExtension: true)
void configureDependencies(
  GetIt getIt, {
  required GenesisConfig config,
  required StringSink errorSink,
  VoiceTransport Function()? voiceTransportFactory,
}) {
  getIt.registerSingleton<GenesisConfig>(config);
  getIt.registerSingleton<StringSink>(errorSink);
  getIt.init();
  registerFactoryFunctions(getIt, voiceTransportFactory: voiceTransportFactory);
}
