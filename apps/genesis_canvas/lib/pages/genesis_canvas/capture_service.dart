import 'package:flutter/widgets.dart';

/// Service de capture du rendu, tel que la page le consomme.
///
/// La couche `app` fournit l'implémentation (`SnapshotService`) : la page ne
/// dépend pas d'elle.
abstract interface class CaptureService {
  /// Vrai si la capture est demandée et autorisée.
  bool get isActive;

  /// Capture le `RepaintBoundary` désigné par [boundaryKey] puis sort.
  Future<void> captureAndExit(GlobalKey boundaryKey);
}
