import 'package:flutter/widgets.dart';

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
  /// lignes au plus puis ellipse, texte d'au moins 24 px (pdr-0074 D9, A7).
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
