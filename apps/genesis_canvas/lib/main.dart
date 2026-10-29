import 'dart:io' show Platform, exit, stderr;

import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'app/config/config_loader.dart';

/// Point d'entrée de l'application.
void main() {
  final config = loadConfigOrExit(
    Platform.environment,
    errorSink: stderr,
    exitHandler: exit,
  );
  if (config == null) return;
  runApp(GenesisCanvasApp(config: config));
}
