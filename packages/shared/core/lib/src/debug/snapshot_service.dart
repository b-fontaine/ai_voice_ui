import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Fonction de sortie du processus (frontière plateforme, `exit` en prod).
typedef ExitHandler = void Function(int code);

/// Capture le rendu d'un `RepaintBoundary` en PNG, puis fait sortir l'app.
///
/// Outil de la boucle de développement : actif seulement en debug **et** si un
/// chemin est fourni (variable `GENESIS_SNAPSHOT`). Succès : `exitHandler(0)` ;
/// échec : message sur [errorSink] puis `exitHandler(1)`.
class SnapshotService {
  SnapshotService({
    required this.path,
    required this.exitHandler,
    required this.errorSink,
    this.debugMode = kDebugMode,
    this.pixelRatio = 1.0,
  });

  /// Chemin du PNG à écrire ; `null` ou vide désactive le service.
  final String? path;
  final ExitHandler exitHandler;

  /// Destination des messages d'erreur (`stderr` en prod).
  final StringSink errorSink;

  /// Vrai en mode debug ; injectable pour tester le mode release.
  final bool debugMode;
  final double pixelRatio;

  bool get isActive => debugMode && (path?.trim().isNotEmpty ?? false);

  /// Capture le `RepaintBoundary` désigné par [boundaryKey] puis sort.
  ///
  /// Ne fait rien si le service est inactif.
  Future<void> captureAndExit(GlobalKey boundaryKey) async {
    if (!isActive) return;
    try {
      final bytes = await _encode(boundaryKey);
      // Écriture synchrone : elle reste fiable sous la fausse horloge des
      // tests de widget, où les E/S asynchrones ne se terminent pas.
      final file = File(path!)..parent.createSync(recursive: true);
      file.writeAsBytesSync(bytes);
    } on Object catch (error) {
      errorSink.writeln('SnapshotService : échec de la capture : $error');
      exitHandler(1);
      return;
    }
    exitHandler(0);
  }

  Future<Uint8List> _encode(GlobalKey boundaryKey) async {
    final renderObject = boundaryKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      throw StateError('aucun RepaintBoundary derrière la clé fournie');
    }
    final ui.Image image = await renderObject.toImage(pixelRatio: pixelRatio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('encodage PNG impossible');
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      image.dispose();
    }
  }
}
