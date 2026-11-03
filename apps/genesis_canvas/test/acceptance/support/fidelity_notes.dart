import 'package:flutter_test/flutter_test.dart';

import 'design_harness.dart';
import 'fidelity_harness.dart';

/// Valeurs relevées par un step et relues par un autre (scénarios A-02, A-04).
abstract final class FidelityNotes {
  /// Dernier nombre relevé par « je note le nombre affiché par l'élément ».
  static double? number;

  /// Opacité propre à une ligne de la checklist : son opacité rendue divisée
  /// par celle du contenu de la surface `checklist` (le fondu d'apparition de
  /// la surface s'y ajoute et n'est pas celui de la cascade).
  static double rowOpacity(String rowKey) {
    final double row = Fidelity.opacity(rowKey);
    final double surface = DesignHarness.renderedOpacity(
      DesignHarness.contentOf('checklist'),
      what: 'le contenu de la surface checklist',
    );
    expect(surface, isNonNegative);
    return surface < 0.05 ? row : row / surface;
  }
}
