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
