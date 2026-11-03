import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Clés de widgets de l'écran de l'acte 1 (spec 007), **source unique** des
/// scénarios d'acceptation S-01 et A1 à A5. T16 les reprend dans les widgets
/// de l'app : une clé renommée ici l'est partout, sinon le scénario échoue.
///
/// Les libellés visibles (« en veille », « aucun agent retenu », « refusé »,
/// « Remettre à vide », « Acte 1/3 », « Données indisponibles », « n / 6
/// utilisés ») sont cherchés par texte : ils font partie du contrat visible.
abstract final class AcceptanceKeys {
  /// Cellule de la surface [id] dans le canevas, présente dès `createSurface`
  /// et quelle que soit la phase (squelette, sans données, complète, neutre).
  /// Les textes affichés par la surface en sont des descendants.
  static Key surface(String id) => Key('surface-$id');

  /// Squelette (`DsSkeleton`) de la surface [id] : visible tant que seule la
  /// phase `createSurface` est passée, descendant de [surface].
  static Key skeleton(String id) => Key('skeleton-$id');

  /// État neutre (`DsNeutralState`, RG-10) de la surface [id], descendant de
  /// [surface] ; il porte le libellé « Données indisponibles ».
  static Key neutral(String id) => Key('neutral-$id');

  /// Contour pointillé (D2) autour de la surface [id] : présent seulement
  /// quand le message en cours du panneau concerne cette surface.
  static Key highlight(String id) => Key('highlight-$id');

  /// Ligne d'un agent du rail (existe déjà : `agent-<nom>`).
  static Key agent(String name) => Key('agent-$name');

  /// Liaison de délégation (spec 015, Q-85) entre l'orchestrateur et la tuile de
  /// l'agent [name] : présente seulement tant que l'agent est « en attente »
  /// ou « en cours ».
  static Key delegationLink(String name) => Key('delegation-link-$name');

  /// Préfixe commun des clés de liaison, pour affirmer qu'aucune n'existe.
  static const String delegationLinkPrefix = 'delegation-link-';

  /// Rail des agents (existe déjà).
  static const Key agentsRail = Key('agents-rail');

  /// Panneau du protocole (toujours monté, replié par défaut).
  static const Key protocolPanel = Key('protocol-panel');

  /// Bouton qui plie et déplie le panneau.
  static const Key protocolToggle = Key('protocol-toggle');

  /// Entrée numéro [n] (depuis 0) du panneau ; absente quand le panneau est
  /// replié ou vide.
  static Key protocolEntry(int n) => Key('protocol-entry-$n');

  /// Toutes les entrées montrées par le panneau (clés `protocol-entry-<n>`).
  static Finder protocolEntries() => find.byWidgetPredicate((widget) {
    final key = widget.key;
    // Les sous-éléments d'une entrée (`protocol-entry-<n>-no`, `-kind`) ne
    // sont pas des entrées.
    return key is ValueKey<String> &&
        RegExp(r'^protocol-entry-\d+$').hasMatch(key.value);
  });

  /// Entrée en cours (mise en évidence) du panneau : exactement une quand le
  /// panneau est déplié et non vide. Elle affiche l'opération et la surface.
  static const Key protocolCurrent = Key('protocol-current');

  /// Étagère du catalogue, avec l'indicateur « n / 6 utilisés ».
  static const Key catalogShelf = Key('catalog-shelf');

  /// Ligne du composant [component] dans l'étagère. Elle affiche le texte
  /// « utilisé » ou « inutilisé » (état en toutes lettres, comme le rail).
  static Key shelfItem(String component) => Key('shelf-$component');

  /// Indicateur d'acte (« Acte n/3 · … ») ; un clic passe à l'acte suivant.
  static const Key actIndicator = Key('act-indicator');

  /// Bouton « Remettre à vide » de la régie.
  static const Key resetButton = Key('reset-button');

  /// Ligne de comparaison (pdr-0064, D2) de la surface [id] (`KeyIndicator`,
  /// `ReviewSentiment`) : un seul `Text` « 3.3 : 99,71 % · −0,28 pt » ou
  /// « 3.3 : 14 % négatifs · +16 pts » (`<label> : <value> · <delta>`), de
  /// couleur neutre (jamais celle d'un statut, RG-09), descendant de
  /// [surface]. Absente quand `comparison` manque ou est incomplet (D7).
  static Key comparison(String id) => Key('comparison-$id');

  /// Entrée de légende de la série [name] dans la courbe (`TrendChart`),
  /// descendante de [surface]`('trend')`, une par série nommée du data model.
  /// La pastille et le nom de la série partagent une couleur stable par rang.
  static Key trendSeries(String name) => Key('trend-series-$name');

  /// Préfixe commun des clés [trendSeries] (pour compter les séries).
  static const String trendSeriesPrefix = 'trend-series-';

  /// Bouton de la Barre d'actions pour l'action [id] (`block_release`,
  /// `validate_release`), descendant de [surface]`('actions')` (spec 009).
  static Key actionButton(String id) => Key('action-$id');

  /// Ligne de rang [rank] (1 à 5) de la `CrashList` (spec 012), descendante de
  /// [surface]`('crashes')`. Absente tant qu'il n'y a pas de données valides.
  static Key crashRow(int rank) => Key('crash-row-$rank');

  /// `Text` du libellé de la ligne de rang [rank] de la `CrashList` : deux
  /// lignes au plus puis ellipse, texte d'au moins 11 px depuis pdr-0087 (pdr-0074 D9, A7).
  static Key crashLabel(int rank) => Key('crash-label-$rank');

  /// Canevas (existe déjà).
  static const Key canvasBoard = Key('canvas-board');

  /// Les quatre surfaces de l'acte 1 (`contracts/a2ui/genesis/v1`).
  static const List<String> act1Surfaces = <String>[
    'kpi',
    'trend',
    'reviews',
    'checklist',
  ];

  /// Agents de l'acte 1 (rôles, RG-29).
  static const List<String> act1Agents = <String>[
    'Qualité',
    'Voix du client',
    'Livraison',
  ];
}

/// Contrat des clés de la fidélité au design system (spec 019, scénarios
/// V-01 à V-11 et A-01 à A-07 de `acte_fidelite_design.feature`).
///
/// Les scénarios cherchent chaque partie d'un composant par une clé
/// `Key('<surface>-<partie>')` (pas de constante : le nom est écrit dans le
/// `.feature`, un finder vide est la raison d'échec tant que la structure
/// n'existe pas). Les tâches TDD T11 à T34 posent ces clés ; une clé renommée
/// l'est ici et dans le `.feature`.
///
/// - **KeyIndicator** (`kpi-`) : `value` (le seul `Text.rich` du chiffre et de
///   l'unité), `gauge` (la piste), `gauge-fill`, `gauge-mark` (marque de seuil)
///   et `gauge-mark-label`, `gauge-ref` (repère de la comparaison) et
///   `gauge-ref-label`, `delta-trend-label` / `delta-trend-value`,
///   `delta-comparison-label` / `delta-comparison-value`. Jauge, marque et
///   repère sont des widgets de la largeur de leur partie (le remplissage fait
///   `largeur du remplissage / largeur de la piste`).
/// - **TrendChart** (`trend-`) : `plot` (zone de tracé), `grid`, `axis` (valeurs
///   de l'axe), `swatch-<série>` (trait de légende), `threshold-legend`, `area`
///   (zone sous la série courante), `breach` (zone de franchissement), `head`
///   (point de tête, sous le fondu de l'apparition), `head-value`, `callout`
///   (annotation), `reveal` (le `ClipRect` à `clipper` du dévoilement). Le
///   texte de l'annotation et de la valeur de tête est un widget `Text` : du
///   texte peint au canevas n'est pas observable.
/// - **ReleaseChecklist** (`checklist-`) : `table`, `head-0` à `head-3`,
///   `cell-<ligne>-<colonne>`, `row-<n>`, `row-<n>-edge` (liseré, présent sur
///   les lignes bloquantes seulement), `verdict` (grande puce), `count`.
/// - **ReviewSentiment** (`reviews-`) : `split` (la barre), `split-pos`,
///   `split-neg`, `legend-pos`, `legend-neg`, `card-<n>`, `card-<n>-meta`
///   (note et plateforme), `card-<n>-text`.
/// - **ActionBar** : `actions-label` (étiquette = `title` de `/actions`),
///   `action-<id>-visual` (le visuel de 44 points ; la cible reste `action-<id>`),
///   `action-<id>-dashes` (bordure en tirets, présente si désactivé).
/// - **Rail** : `agents-rail-label`, `agent-tile-<nom>` (tuile, bordure),
///   `agent-dot-<nom>`, `agent-state-<nom>`, `agent-bar-<nom>` (barre
///   indéterminée, présente seulement quand l'agent travaille).
/// - **Barre vocale** : `voice-orb-core`, `voice-orb-ring-0` à `-2`,
///   `voice-wave`, `transcript-user-who`, `transcript-ai-who`,
///   `transcript-ai-caret`, `act-segment-1` à `-3`, `mic-button-visual`,
///   `mic-rec-dot`, `silence-button-visual`, `reset-button-visual` (visuels de
///   34 points ; les cibles de 48 points restent `mic-button`, etc.).
/// - **Cadre de génération** : `generation-frame-<surface>` (sur le
///   `RepaintBoundary` du cadre, sous son fondu), `generation-frame-<surface>-tag`.
/// - **Pied** : `shelf-<composant>` (puce), `replay-play-visual`,
///   `replay-track`, `replay-track-fill`, `replay-track-knob`,
///   `replay-speed-<v>-visual`, `replay-direct-dot`, `protocol-entry-<n>-no`
///   (« #nn ») et `protocol-entry-<n>-kind`.
///
/// Mouvement : toute boucle (`voice-wave`, `voice-orb-ring-n`,
/// `generation-frame-*`) porte ou contient son propre `RepaintBoundary` ; son
/// fondu éventuel est un widget d'opacité au-dessus de la clé.
abstract final class FidelityKeysContract {}
