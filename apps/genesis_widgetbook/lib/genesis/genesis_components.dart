import 'package:flutter/widgets.dart';
import 'package:shared_design_system/shared_design_system.dart'
    show SceneMotionScope;

import 'genesis_surface_host.dart';

// Un widget par composant du catalogue genesis, nommé comme lui : Widgetbook
// nomme un composant d'après le type de son constructeur, et le test du
// catalogue compare ces noms à `GenesisContract.components`. Les vues réelles
// sont privées à `feature_canvas` ; ces classes ne font que choisir l'exemple
// du contrat que l'hôte rejoue.

/// `KeyIndicator` : surface `kpi` (`act1-kpi.jsonl`).
class KeyIndicator extends GenesisSurfaceHost {
  const KeyIndicator({super.key, super.state}) : super(example: 'act1-kpi');
}

/// `TrendChart` : surface `trend` (`act1-trend.jsonl`).
class TrendChart extends GenesisSurfaceHost {
  const TrendChart({super.key, super.state}) : super(example: 'act1-trend');
}

/// `ReviewSentiment` : surface `reviews` (`act1-reviews.jsonl`).
class ReviewSentiment extends GenesisSurfaceHost {
  const ReviewSentiment({super.key, super.state})
    : super(example: 'act1-reviews');
}

/// `ReleaseChecklist` : surface `checklist` (`act1-checklist.jsonl`).
class ReleaseChecklist extends GenesisSurfaceHost {
  const ReleaseChecklist({super.key, super.state})
    : super(example: 'act1-checklist');
}

/// `ActionBar` : surface `actions` (`act2-actions.jsonl`).
class ActionBar extends GenesisSurfaceHost {
  const ActionBar({super.key, super.state}) : super(example: 'act2-actions');
}

/// `CrashList` : surface `crashes` (`crashlist-global.jsonl`).
class CrashList extends GenesisSurfaceHost {
  const CrashList({super.key, super.state})
    : super(example: 'crashlist-global');
}

/// Enveloppe commune des stories genesis : animations coupées pour des
/// captures stables (`SceneMotionScope`, RG-09 : le thème de scène vient de
/// `sceneAppBuilder`).
Widget genesisStorySetup(Widget child) =>
    SceneMotionScope(disabled: true, child: child);
