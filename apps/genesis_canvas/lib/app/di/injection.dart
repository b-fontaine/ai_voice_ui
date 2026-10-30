import 'package:feature_voice_session/feature_voice_session.dart'
    show VoiceTransport;
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_core/shared_core.dart' show AppClock;

import '../config/genesis_config.dart';
import 'app_module.dart';
import 'injection.config.dart';

/// Enregistre les dépendances dans l'instance de [GetIt] passée en paramètre
/// (aucune variable globale : l'injection se fait par constructeur, et
/// chaque app crée sa propre instance, sans état résiduel).
///
/// [config] est enregistrée AVANT l'`init` généré, dont les modules la
/// consomment. [clock] (frontière « temps ») et [voiceTransportFactory]
/// (frontière plateforme) sont les substitutions permises, pour les tests ;
/// [clock] remplace l'horloge système du graphe (voir `AppModule.clock`).
/// [voiceTransportFactory] tient lieu de fabrique de transport du graphe (voir `registerFactoryFunctions`). [errorSink] reçoit
/// les diagnostics (phrases fermées) et est enregistré dans le graphe.
@InjectableInit(initializerName: 'init', asExtension: true)
void configureDependencies(
  GetIt getIt, {
  required GenesisConfig config,
  required StringSink errorSink,
  AppClock? clock,
  VoiceTransport Function()? voiceTransportFactory,
}) {
  getIt.registerSingleton<GenesisConfig>(config);
  getIt.registerSingleton<StringSink>(errorSink);
  getIt.init();
  if (clock != null) {
    // Remplacement avant toute résolution : l'horloge système du graphe
    // (lazy, jamais instanciée à ce stade) cède la place à celle du test.
    getIt.unregister<AppClock>();
    getIt.registerSingleton<AppClock>(clock);
  }
  registerFactoryFunctions(getIt, voiceTransportFactory: voiceTransportFactory);
}
