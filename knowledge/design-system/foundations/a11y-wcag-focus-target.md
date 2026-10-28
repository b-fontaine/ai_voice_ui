---
id: ds-a11y-wcag-focus-target
title: Accessibilité — focus, taille des cibles et texte agrandi (WCAG 2.2)
tags: [accessibility, wcag, focus, target-size, desktop]
status: verified
updated: 2026-10-27
sources: [https://www.w3.org/TR/WCAG22/, https://www.w3.org/WAI/WCAG22/Understanding/focus-not-obscured-minimum.html, https://www.w3.org/WAI/WCAG22/Understanding/focus-appearance.html, https://docs.flutter.dev/ui/accessibility/accessibility-testing]
links: [ds-a11y-wcag-contrast, ds-a11y-flutter-signals, ux-desktop-focus, ux-desktop-pointer-hover, ds-spacing-shape-elevation, test-golden-alchemist]
---
# Focus visible et non masqué, cibles d'au moins 24 px, texte jusqu'à 200 %

## Focus (WCAG 2.2)
- **2.4.7 Focus Visible, AA :** une interface utilisable au clavier offre un mode où le focus clavier est visible.
- **2.4.11 Focus Not Obscured (Minimum), AA :** l'élément focalisé n'est pas **entièrement** masqué par du contenu de l'auteur (en-tête sticky, dialogue non modal, bannière). Un masquage partiel est admis.
- **2.4.12 (AAA) :** aucun masquage, même partiel.
- **2.4.13 Focus Appearance, AAA (pas AA) :**
  - l'indicateur couvre au moins un périmètre de **2 px CSS** autour du composant ;
  - il présente **3:1** entre les mêmes pixels, focalisé contre non focalisé ;
  - exception : l'indicateur est géré par l'agent utilisateur et l'auteur ne le modifie pas.

## Cibles de pointeur
- **2.5.8 Target Size (Minimum), AA :** 24 × 24 px CSS. Cinq exceptions :
  - **Spacing :** des cercles de 24 px centrés sur chaque petite cible ne coupent ni une autre cible ni le cercle d'une autre ;
  - **Equivalent**, **Inline**, **User Agent Control**, **Essential** (y compris une obligation légale).
- **2.5.5 Target Size (Enhanced), AAA :** 44 × 44 px CSS, mêmes exceptions sauf Spacing. Understanding 2.5.8 suggère de viser 2.5.5 pour les contrôles importants.
- La doc Flutter recommande **48 × 48** pour toutes les cibles tactiles (`androidTapTargetGuideline`), 44 × 44 pour iOS.

## Texte
- **1.4.4 Resize Text, AA :** texte agrandi jusqu'à **200 %** sans perte de contenu ni de fonction (hors sous-titres et images de texte).
- **1.4.12 Text Spacing, AA :** rien ne se perd avec une hauteur de ligne ≥ 1,5 × la police, un espace après paragraphe ≥ 2 ×, un interlettrage ≥ 0,12 × et un espacement des mots ≥ 0,16 ×.

## Norme interne du DS (opinion)
- **Partout :** au moins 2.5.8 (24 × 24) ; l'exception Spacing ne sert que pour les barres d'outils denses du desktop.
- **Contrôles importants** (envoyer, micro, valider une action GenUI) : 44 × 44.
- **Tactile :** 48 × 48, comme la doc Flutter.
- Le DS vise 2.4.13 même s'il est AAA : anneau de 2 px en rôle `primary` ou `outline`, à 3:1 ([[ds-color-m3-roles]]).
- Goldens avec `textScaler: TextScaler.linear(2)` pour couvrir 1.4.4 (`textScaleFactor` est déprécié, voir [[ds-a11y-flutter-signals]] et [[test-golden-alchemist]]).

## ⚠️ Pièges
- Ne pas confondre 2.4.11 (masquage, AA) et 2.4.13 (apparence, AAA).
- Un panneau sticky (transcription vocale, barre d'outils) peut masquer le champ focalisé : risque 2.4.11.
- Le chiffre de 44 px vient du texte normatif 2.5.5, pas de la page Understanding 2.5.8.
