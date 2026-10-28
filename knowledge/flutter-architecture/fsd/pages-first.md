---
id: arch-fsd-pages-first
title: FSD v2.1 — « pages first » plutôt que découpage précoce
tags: [fsd, decomposition, v2.1]
status: verified
updated: 2026-10-28
sources: [https://feature-sliced.design/docs/guides/migration/from-v2-0]
links: [arch-fsd-layers, arch-official-use-cases]
---
# v2.1 : décomposer d'abord par page, extraire ensuite

« Le principal changement de v2.1 est le nouveau modèle mental de décomposition : **pages first**. »

- **v2.0** : on commençait par identifier finement les `entities` et les `features`, puis on les assemblait.
- **v2.1** : on garde l'UI et la logique **dans la page** et on s'appuie sur `shared`. On ne descend dans une couche inférieure que lorsque **plusieurs pages** ont besoin de la même logique.
- Pas de changement cassant : un projet v2.0 reste valide.
- Steiger fournit deux règles :
  - `insignificant-slice` : une slice utilisée par une seule page ;
  - `excessive-slicing` : trop de slices dans une couche.

**Conséquence pour une app multi-agents (opinion) :**
- Ne pas créer d'emblée 15 features.
- Les capacités réellement partagées justifient des slices basses. C'est le cas des agents :
  - la session voix est utilisée par plusieurs écrans et par l'orchestrateur ;
  - le rendu GenUI aussi.
- Un écran de réglages reste une page autonome.

C'est le même esprit que la doc Flutter sur les use-cases : « seulement quand c'est nécessaire » (`arch-official-use-cases`).
