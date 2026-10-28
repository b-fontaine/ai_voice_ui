---
id: ds-a11y-wcag-contrast
title: Accessibilité — contraste WCAG 2.2 (et APCA)
tags: [accessibility, wcag, contrast, apca, design-system]
status: sourced
updated: 2026-10-27
sources: [https://www.w3.org/TR/WCAG22/, https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html, https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html, https://www.w3.org/TR/wcag-3.0/, https://github.com/Myndex/apca-introduction]
links: [ds-color-m3-roles, ds-a11y-wcag-focus-target, ds-a11y-flutter-signals, ds-color-dark-contrast, ds-widgetbook-testing]
---
# WCAG 2.2 AA fait foi pour le contraste ; APCA reste informatif

WCAG 2.2 est une Recommandation W3C du **2024-12-12** (édition mise à jour ; la première date du 2023-10-05).

## Texte
- **1.4.3 Contrast (Minimum), AA :** 4.5:1 pour le texte, **3:1** pour le grand texte.
- **Grand texte :** au moins 18 pt, ou 14 pt gras. Avec 1 pt = 1,333 px CSS : environ 24 px et 18,5 px.
- **Exceptions :** texte d'un composant inactif, logos et noms de marque, décoration pure, texte invisible, texte d'une image au contenu visuel important.
- **1.4.6 Contrast (Enhanced), AAA :** 7:1, et 4.5:1 pour le grand texte. Mêmes exceptions.
- **Pas d'arrondi :** 4.499:1 échoue à 4.5:1 (Understanding 1.4.3). De même, 2.999:1 échoue à 3:1 (Understanding 1.4.11).

## Non-texte
- **1.4.11 Non-text Contrast, AA :** 3:1 contre les couleurs adjacentes pour identifier un composant d'UI et ses états, et pour les parties de graphiques nécessaires à la compréhension.
- Les composants inactifs (disabled) sont exemptés.
- Les états (sélectionné, focalisé) doivent atteindre 3:1.
- Un **hover** purement supplémentaire n'a pas à atteindre 3:1, si le composant garde son propre contraste.
- **1.4.1 Use of Color, A :** la couleur ne doit jamais être le seul moyen de porter une information ou un état.

## WCAG 3 et APCA
- WCAG 3.0 est un **Working Draft** (version du 2026-09-10). « Text contrast sufficient (minimum) » contient encore `@@[contrast measure to be determined]` : APCA n'est pas normatif.
- Niveaux Lc « Bronze » selon le dépôt de l'auteur d'APCA (source secondaire) :
  - Lc90 préféré pour le corps de texte, Lc75 minimum (≥ 18px/400) ;
  - Lc60 pour le texte fluide (> 24px, ou 16px gras), Lc45 pour le grand texte (> 36px, ou 24px gras) ;
  - Lc30 minimum absolu, Lc15 seuil d'invisibilité.

## Règle du DS (opinion)
- La conformité se juge **en WCAG 2.2 AA** : chaque paire de rôles du thème est testée, ratio brut, sans arrondi.
- APCA peut figurer dans le rapport Widgetbook comme information, jamais comme critère de passage ([[ds-widgetbook-testing]]).
- Les paires M3 ne garantissent que 3:1 ([[ds-color-m3-roles]]) : tester explicitement les paires porteuses de texte à 4.5:1.

## ⚠️ Pièges
- Les tables Lc tierces divergent (gihyo.jp, brainy.ink), et aucune page w3.org ne fixe de valeur Lc.
- Un état « erreur » signalé par la seule couleur rouge viole 1.4.1 : ajouter une icône ou un texte.
