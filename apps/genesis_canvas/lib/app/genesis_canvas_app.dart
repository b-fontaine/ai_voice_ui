import 'package:flutter/widgets.dart';

import '../pages/genesis_canvas/genesis_canvas.dart';

/// Racine de l'application.
///
/// Les paramètres fixent le contrat de lancement visé par la fonctionnalité
/// 000 : scénario de rejeu, chemin de la capture PNG et fonction de sortie
/// (frontière plateforme, remplaçable par les tests). Ils sont consommés par
/// les tâches suivantes.
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
  Widget build(BuildContext context) => const Directionality(
    textDirection: TextDirection.ltr,
    child: GenesisCanvasPage(),
  );
}
