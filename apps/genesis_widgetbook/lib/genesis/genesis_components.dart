import 'package:flutter/widgets.dart';
import 'package:shared_design_system/shared_design_system.dart'
    show SceneMotionScope;

import 'genesis_surface_host.dart';

// Un widget par composant du catalogue genesis, nommé comme lui : Widgetbook
// nomme un composant d'après le type de son constructeur, et le test du
// catalogue compare ces noms à `GenesisContract.components`. Les vues réelles
// sont privées à `feature_canvas` ; ces classes ne font que choisir l'exemple
// du contrat que l'hôte rejoue.

const String _kpi = 'act1-kpi';
const String _trend = 'act1-trend';
const String _reviews = 'act1-reviews';
const String _checklist = 'act1-checklist';
const String _actions = 'act2-actions';
const String _crashes = 'crashlist-global';

/// Exemples du contrat par composant (sans extension). Source unique, lue par
/// les six classes ci-dessous et par `examples_assets_test.dart`.
const Map<String, String> genesisExamples = <String, String>{
  'KeyIndicator': _kpi,
  'TrendChart': _trend,
  'ReviewSentiment': _reviews,
  'ReleaseChecklist': _checklist,
  'ActionBar': _actions,
  'CrashList': _crashes,
};

/// `KeyIndicator` : surface `kpi` (`act1-kpi.jsonl`).
class KeyIndicator extends GenesisSurfaceHost {
  const KeyIndicator({super.key, super.state}) : super(example: _kpi);
}

/// `TrendChart` : surface `trend` (`act1-trend.jsonl`).
class TrendChart extends GenesisSurfaceHost {
  const TrendChart({super.key, super.state}) : super(example: _trend);
}

/// `ReviewSentiment` : surface `reviews` (`act1-reviews.jsonl`).
class ReviewSentiment extends GenesisSurfaceHost {
  const ReviewSentiment({super.key, super.state}) : super(example: _reviews);
}

/// `ReleaseChecklist` : surface `checklist` (`act1-checklist.jsonl`).
class ReleaseChecklist extends GenesisSurfaceHost {
  const ReleaseChecklist({super.key, super.state}) : super(example: _checklist);
}

/// `ActionBar` : surface `actions` (`act2-actions.jsonl`).
class ActionBar extends GenesisSurfaceHost {
  const ActionBar({super.key, super.state}) : super(example: _actions);
}

/// `CrashList` : surface `crashes` (`crashlist-global.jsonl`).
class CrashList extends GenesisSurfaceHost {
  const CrashList({super.key, super.state}) : super(example: _crashes);
}

/// Enveloppe commune des stories genesis : animations coupées pour des
/// captures stables (`SceneMotionScope`, RG-09 : le thème de scène vient de
/// `sceneAppBuilder`).
Widget genesisStorySetup(Widget child) =>
    SceneMotionScope(disabled: true, child: child);
