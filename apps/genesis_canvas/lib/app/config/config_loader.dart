import 'package:shared_core/shared_core.dart' show ExitHandler;

import 'genesis_config.dart';

/// Lit la configuration de l'environnement. Si elle est invalide, écrit le
/// message (sans la valeur fautive) sur [errorSink], appelle [exitHandler]
/// avec le code 2 et renvoie `null`.
GenesisConfig? loadConfigOrExit(
  Map<String, String> environment, {
  required StringSink errorSink,
  required ExitHandler exitHandler,
}) {
  try {
    return GenesisConfig.fromEnvironment(environment);
  } on GenesisConfigException catch (error) {
    errorSink.writeln(error.message);
    exitHandler(2);
    return null;
  }
}
