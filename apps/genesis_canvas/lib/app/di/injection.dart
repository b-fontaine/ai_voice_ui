import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'injection.config.dart';

/// Environnement du câblage réel (par opposition aux faux des tests).
const Environment liveEnvironment = Environment('live');

/// Enregistre les dépendances dans l'instance de [GetIt] passée en paramètre
/// (aucune variable globale : l'injection se fait par constructeur).
@InjectableInit(initializerName: 'init', asExtension: true)
void configureDependencies(GetIt getIt, {String? environment}) =>
    getIt.init(environment: environment);
