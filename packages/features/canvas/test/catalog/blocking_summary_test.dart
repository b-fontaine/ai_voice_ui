import 'package:feature_canvas/src/catalog/blocking_summary.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

/// Compteur de la checklist : « n bloquants / total », déduit des codes
/// `level` des critères, jamais de leurs libellés (plan 019 P1).
void main() {
  const SceneStatus ok = SceneStatus.ok;
  const SceneStatus risk = SceneStatus.risk;
  const SceneStatus blocking = SceneStatus.blocking;

  final List<(List<SceneStatus>, String)> cases = <(List<SceneStatus>, String)>[
    (<SceneStatus>[blocking, blocking, ok], '2 bloquants / 3'),
    (<SceneStatus>[ok, risk, ok], '0 bloquant / 3'),
    (<SceneStatus>[risk, blocking, ok], '1 bloquant / 3'),
    (<SceneStatus>[blocking], '1 bloquant / 1'),
    (<SceneStatus>[], '0 bloquant / 0'),
    (<SceneStatus>[blocking, blocking, blocking, risk], '3 bloquants / 4'),
  ];

  for (final (List<SceneStatus> levels, String text) in cases) {
    test('${levels.map((SceneStatus s) => s.name).join(', ')} : $text', () {
      expect(blockingSummary(levels), text);
    });
  }

  test('le nombre de bloquants ne compte que le code blocking', () {
    expect(blockingCount(<SceneStatus>[ok, risk, blocking, blocking]), 2);
    expect(blockingCount(const <SceneStatus>[]), 0);
  });
}
