import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

import '../support/scene_style_harness.dart';

/// Usage: parmi les statuts, seul le statut {'blocking'} bat en continu
///
/// Une puce « bat » quand un `Listenable` placé dans son sous-arbre, ou sur la
/// chaîne de ses ancêtres jusqu'au premier qui contient une puce d'un autre
/// statut (animation d'un `AnimatedWidget`, `AnimatedBuilder` ou
/// `ListenableBuilder`, ou `CustomPainter` d'un `CustomPaint`, qui est lui-même
/// un `Listenable`), notifie dans chacun des deux intervalles consécutifs
/// (250 ms, puis 130 ms) et, s'il s'agit d'une animation, est encore en cours
/// à la fin. Une animation finie (apparition, changement de statut) ne compte
/// pas.
Future<void> parmiLesStatutsSeulLeStatutBatEnContinu(
  WidgetTester tester,
  String beating,
) async {
  final SceneStatus expected = SceneStatusCode.of(beating);
  final Map<SceneStatus, Set<Listenable>> listenables =
      <SceneStatus, Set<Listenable>>{
        for (final SceneStatus s in SceneStatus.values) s: <Listenable>{},
      };
  for (final SceneStatus status in SceneStatus.values) {
    final Finder chips = SceneStyleHarness.chips(status);
    for (final Element chip in chips.evaluate()) {
      listenables[status]!.addAll(_listenablesOf(chip, status));
    }
  }

  expect(
    SceneStatus.values.any(
      (SceneStatus s) => SceneStyleHarness.chips(s).evaluate().isNotEmpty,
    ),
    isTrue,
    reason: "aucune puce de statut n'est affichée",
  );

  // Notifications reçues, par `Listenable` et par intervalle.
  var window = 0;
  final Map<Listenable, List<int>> counts = <Listenable, List<int>>{};
  final Map<Listenable, VoidCallback> counters = <Listenable, VoidCallback>{};
  for (final Set<Listenable> set in listenables.values) {
    for (final Listenable l in set) {
      final List<int> perWindow = counts.putIfAbsent(l, () => <int>[0, 0]);
      counters[l] = () => perWindow[window]++;
      l.addListener(counters[l]!);
    }
  }
  await tester.pump(const Duration(milliseconds: 250));
  window = 1;
  await tester.pump(const Duration(milliseconds: 130));
  counters.forEach((Listenable l, VoidCallback c) => l.removeListener(c));

  bool loops(Listenable l) {
    final List<int> perWindow = counts[l]!;
    final bool ongoing = l is! Animation<double> || l.status.isAnimating;
    return perWindow[0] > 0 && perWindow[1] > 0 && ongoing;
  }

  // Les statuts absents de l'écran ne sont pas jugés : à l'acte 1 aucune puce
  // « blocking » n'existe encore.
  final Set<SceneStatus> beats = <SceneStatus>{
    for (final MapEntry<SceneStatus, Set<Listenable>> e in listenables.entries)
      if (e.value.any(loops)) e.key,
  };
  final Set<SceneStatus> shown = <SceneStatus>{
    for (final SceneStatus s in SceneStatus.values)
      if (SceneStyleHarness.chips(s).evaluate().isNotEmpty) s,
  };
  expect(
    beats,
    shown.contains(expected) ? <SceneStatus>{expected} : <SceneStatus>{},
    reason:
        'statuts qui battent : ${beats.map((s) => s.name).toList()} '
        '(statuts affichés : ${shown.map((s) => s.name).toList()}), '
        'seul « ${expected.name} » peut battre',
  );
}

/// `Listenable` qui pilotent la puce [chip] : ceux de son sous-arbre et ceux
/// de ses ancêtres, jusqu'au premier ancêtre qui contient aussi une puce d'un
/// autre statut.
Set<Listenable> _listenablesOf(Element chip, SceneStatus status) {
  final Set<Listenable> found = <Listenable>{};
  void collect(Widget widget) {
    switch (widget) {
      case AnimatedWidget(:final Listenable listenable):
        if (listenable is Animation<double>) found.add(listenable);
      case CustomPaint(:final CustomPainter? painter, :final foregroundPainter):
        if (painter != null) found.add(painter);
        if (foregroundPainter != null) found.add(foregroundPainter);
      default:
    }
  }

  void walk(Element element) {
    collect(element.widget);
    element.visitChildren(walk);
  }

  walk(chip);
  chip.visitAncestorElements((Element ancestor) {
    var mixed = false;
    void look(Element e) {
      final Widget w = e.widget;
      if (w is DsStatusChip && w.status != status) mixed = true;
      if (!mixed) e.visitChildren(look);
    }

    ancestor.visitChildren(look);
    if (mixed) return false;
    collect(ancestor.widget);
    return true;
  });
  return found;
}

/// Convertit le code de statut du scénario.
abstract final class SceneStatusCode {
  static SceneStatus of(String code) {
    final SceneStatus? status = SceneStatus.fromCode(code);
    if (status == null) throw ArgumentError('statut inconnu « $code »');
    return status;
  }
}
