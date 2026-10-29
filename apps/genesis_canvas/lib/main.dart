import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'app/config/genesis_config.dart';

export 'app/app.dart' show GenesisCanvasApp;

/// Point d'entrée de l'application.
void main() {
  final config = GenesisConfig.fromEnvironment(Platform.environment);
  runApp(GenesisCanvasApp(config: config));
}
