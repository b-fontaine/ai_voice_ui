import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_design_system/shared_design_system.dart';

import '../support/scene_style_harness.dart';

/// Usage: parmi les statuts, seul le statut {'blocking'} bat en continu
///
/// Une puce « bat » quand une animation (`AnimatedWidget`, `AnimatedBuilder`,
/// `ListenableBuilder`) placée dans son sous-arbre, ou sur la chaîne de ses
/// ancêtres jusqu'au premier qui contient une puce d'un autre statut, change
/// de valeur et reste en cours à trois instants espacés. Une animation finie
/// (apparition, changement de statut) ne compte pas.
Future<void> parmiLesStatutsSeulLeStatutBatEnContinu(
  WidgetTester tester,
  String beating,
) async {
  final SceneStatus expected = SceneStatusCode.of(beating);
  final Map<SceneStatus, Set<Animation<double>>> animations =
      <SceneStatus, Set<Animation<double>>>{
        for (final SceneStatus s in SceneStatus.values)
          s: <Animation<double>>{},
      };
  for (final SceneStatus status in SceneStatus.values) {
    final Finder chips = SceneStyleHarness.chips(status);
    for (final Element chip in chips.evaluate()) {
      animations[status]!.addAll(_animationsOf(chip, status));
    }
  }

  final Map<Animation<double>, List<double>> samples =
      <Animation<double>, List<double>>{};
  void sample() {
    for (final Set<Animation<double>> set in animations.values) {
      for (final Animation<double> a in set) {
        samples.putIfAbsent(a, () => <double>[]).add(a.value);
      }
    }
  }

  expect(
    SceneStatus.values.any(
      (SceneStatus s) => SceneStyleHarness.chips(s).evaluate().isNotEmpty,
    ),
    isTrue,
    reason: "aucune puce de statut n'est affichée",
  );
  sample();
  await tester.pump(const Duration(milliseconds: 250));
  sample();
  await tester.pump(const Duration(milliseconds: 130));
  sample();

  bool loops(Animation<double> a) {
    final List<double> v = samples[a]!;
    final bool moving = v[0] != v[1] || v[1] != v[2];
    return moving && a.status.isAnimating;
  }

  // Les statuts absents de l'écran ne sont pas jugés : à l'acte 1 aucune puce
  // « blocking » n'existe encore.
  final Set<SceneStatus> beats = <SceneStatus>{
    for (final MapEntry<SceneStatus, Set<Animation<double>>> e
        in animations.entries)
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

/// Animations qui pilotent la puce [chip] : celles de son sous-arbre et celles
/// de ses ancêtres, jusqu'au premier ancêtre qui contient aussi une puce d'un
/// autre statut.
Set<Animation<double>> _animationsOf(Element chip, SceneStatus status) {
  final Set<Animation<double>> found = <Animation<double>>{};
  void collect(Widget widget) {
    final Listenable? listenable = switch (widget) {
      AnimatedWidget(:final Listenable listenable) => listenable,
      _ => null,
    };
    if (listenable is Animation<double>) found.add(listenable);
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
