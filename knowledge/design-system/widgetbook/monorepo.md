---
id: ds-widgetbook-monorepo
title: Widgetbook en monorepo — un catalogue racine ou un par package
tags: [widgetbook, monorepo, pub-workspaces, melos, design-system]
status: verified
updated: 2026-10-28
sources: [https://docs.widgetbook.io/essentials/monorepo]
links: [ds-widgetbook-setup, ds-widgetbook-testing, arch-pub-workspaces, ds-package-structure, arch-recommended-structure]
---
# En monorepo, la doc propose un Widgetbook racine ou un Widgetbook par package

> Référence Widgetbook 3.x. Pour la 4.0 bêta, voir [[ds-widgetbook-4-setup]] (adoption assumée d'une bêta : [[adr-0008-ds-widgetbook-4-beta]]).

Au 2026-10-27, la page monorepo de la doc officielle décrit deux approches.

## 1. Un seul Widgetbook à la racine
```
monorepo/
  widgetbook/            # dépend en path de :
  packages/my_design_system/
  my_app/
```
Un catalogue unique, qui référence le DS et l'app via des dépendances `path`.

## 2. Un Widgetbook par package
`packages/my_design_system/widgetbook/`, et aussi `my_app/widgetbook/` : chaque package porte son propre catalogue.

## Melos
Avec Melos, il peut falloir passer par des **dépendances versionnées** plutôt que `path`, et ajouter `widgetbook/` à la liste `packages` de `melos.yaml`.

## Recommandation (opinion)
- **Un seul catalogue** (par exemple `apps/<catalogue>`), déclaré membre du pub workspace racine ([[arch-pub-workspaces]]). Il dépend du package DS (et plus tard des slices UI qui l'utilisent).
- Raisons : une seule app à builder (pour toutes les plateformes cibles), une seule config d'addons/thèmes, un seul point d'entrée pour la revue et `widgetbook coverage` ([[ds-widgetbook-testing]]).
- Le package DS ne dépend **jamais** de Widgetbook : la dépendance va du catalogue vers le DS.
- Pas de Melos tant que les pub workspaces suffisent.

## ⚠️ Pièges
- **Non vérifié :** la doc Widgetbook ne parle que de dépendances `path` et de Melos. Elle ne dit rien des pub workspaces (`resolution: workspace`). Vérifier que `build_runner` et le générateur fonctionnent dans un membre de workspace avant de figer la structure.
- Nommer l'app catalogue `widgetbook` entre en conflit avec le package `widgetbook` : la nommer autrement (`widgetbook_workspace` dans le quick start, voir [[ds-widgetbook-setup]]).
