---
id: ds-widgetbook-cloud
title: Widgetbook Cloud — builds CLI, Turbo, visual PR, revues Figma
tags: [widgetbook, widgetbook-cloud, ci, visual-review, figma, design-system]
status: verified
updated: 2026-10-28
sources: [https://docs.widgetbook.io/llms.txt, https://docs.widgetbook.io/cloud/builds/turbo, https://docs.widgetbook.io/cloud/reviews, https://docs.widgetbook.io/cloud/snapshots/overview]
links: [adr-0006-ds-no-widgetbook-cloud, ds-widgetbook-publish-web, ds-widgetbook-cloud-multi-snapshot, ds-widgetbook-testing, test-coverage-ci]
---
> Référence.

# Widgetbook Cloud : un catalogue publié et revu à chaque PR

Service SaaS de l'éditeur, payant, facturé **au snapshot et par mois**.

## Fonctionnement
- **Build :** la CI pousse le catalogue avec `widgetbook cloud build push`.
- **Turbo Builds :** si le hash est inchangé, le build précédent est réutilisé. Désactivation par `--no-turbo`. Peu fiable quand des URL externes ou des requêtes réseau changent le rendu.
- **Visual pull request :** une revue est créée automatiquement pour la PR d'un dépôt connecté (GitHub, GitLab, Azure, Bitbucket). Elle compare les builds base et head, sans écrire de test golden, et son URL est publiée comme *commit status*. Seule une **demande de changements** (« request changes ») **bloque le merge** ; c'est désactivable dans les réglages du projet. La doc ne dit pas explicitement qu'une revue simplement non approuvée ne bloque pas.
- **Exclusion :** `cloudExclude: true` sur `@UseCase` retire un use case des snapshots (donc de la facture).
- **Revues Figma :** comparaison des widgets avec les maquettes (paramètre `designLink` du use case).
- **Codemagic** n'est qu'une intégration CI : il faut tout de même un VCS connecté.

## Alternative sans Cloud
Décision de s'en passer : [[adr-0006-ds-no-widgetbook-cloud]] ; publication auto-hébergée : [[ds-widgetbook-publish-web]].

## ⚠️ Pièges
- Pour que Turbo soit fiable, interdire tout appel réseau dans les use cases : uniquement des fixtures locales.
- Animations et valeurs aléatoires faussent la comparaison : voir [[ds-widgetbook-testing]].
