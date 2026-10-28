---
id: ds-atomic-design
title: Atomic Design (Frost) et sa projection en Flutter
tags: [atomic-design, design-system, composition, architecture, widgets]
status: sourced
updated: 2026-10-27
sources: [https://atomicdesign.bradfrost.com/chapter-2/, https://docs.flutter.dev/resources/architectural-overview]
links: [ds-package-structure, ds-component-api, genui-custom-catalog-item, arch-clean-fsd-combo, ux-genui-catalog-as-ds]
---
# Atomic Design est un modèle mental en 5 niveaux, pas un processus linéaire

## Les 5 niveaux chez Brad Frost
- **Atoms** : éléments de base (label, champ, bouton). Ils cessent d'être fonctionnels si on les découpe encore ; c'est l'atome que Frost appelle « plus petite unité fonctionnelle ».
- **Molecules** : groupe simple d'éléments qui fonctionnent comme une unité (label + champ + bouton = recherche), rattaché au principe de responsabilité unique.
- **Organisms** : composant complexe fait de molécules, d'atomes ou d'autres organismes, formant une section distincte (en-tête = logo + navigation + recherche).
- **Templates** : objet de niveau page qui place les composants et montre la structure du contenu.
- **Pages** : instance d'un template remplie de contenu réel représentatif, pour vérifier que le système tient.

Frost insiste : pas de processus linéaire, mais un modèle pour penser **en même temps** le tout et les parties. Il accepte d'autres taxonomies (« elements, modules, components » ; GE : Principles, Basics, Components, Templates, Features, Applications). La bonne taxonomie est celle qui aide l'organisation à communiquer.

## Composition en Flutter
L'aperçu d'architecture Flutter privilégie la composition : on compose des widgets au lieu de sous-classer `Container`. La hiérarchie est peu profonde et large, faite de petits widgets qui font une seule chose. (Opinion) Atomic Design s'y projette naturellement ; la doc Flutter ne le mentionne pas.

## Projection dans le projet (opinion)
| Niveau | Emplacement |
|---|---|
| atoms, molecules, organisms | package design system ([[ds-package-structure]]) |
| templates | layouts et scaffolds adaptatifs du DS (sans données métier) |
| pages | écrans des features/pages FSD, **hors DS** |

- Les widgets du DS sont des **widgets de présentation purs** : données et callbacks en paramètres, aucun Bloc, aucun `getIt`, aucun appel réseau.
- Les items du catalogue GenUI réutilisent les molécules et organismes du DS ([[genui-custom-catalog-item]]).
- Ranger les use cases Widgetbook par niveau, pour rendre la taxonomie visible.

## ⚠️ Pièges
- (opinion, sans source primaire) Risque de sur-décomposition : extraire en atome un widget utilisé une seule fois ajoute de l'API sans réutilisation. Ne promouvoir dans le DS qu'un widget réutilisé.
- Ne pas confondre « page » Atomic Design et `pages/` FSD : les deux finissent hors du DS, mais la page FSD porte l'état (Bloc) et la DI.
