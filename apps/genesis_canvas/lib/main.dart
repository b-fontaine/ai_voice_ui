import 'package:flutter/widgets.dart';

/// Point d'entrée minimal : l'application n'a pas encore de comportement.
void main() {
  runApp(const GenesisCanvasApp());
}

/// Coque vide de l'application.
///
/// Les paramètres fixent le contrat de lancement visé par la fonctionnalité
/// 000 : scénario de rejeu, chemin de la capture PNG et fonction de sortie
/// (frontière plateforme, remplaçable par les tests).
class GenesisCanvasApp extends StatelessWidget {
  const GenesisCanvasApp({
    super.key,
    this.scenario,
    this.snapshotPath,
    this.exitHandler,
  });

  final String? scenario;
  final String? snapshotPath;
  final void Function(int code)? exitHandler;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
