---
id: adr-0006-ds-no-widgetbook-cloud
title: "ADR-0006 — Pas de Widgetbook Cloud"
tags: [adr, decision, widgetbook, widgetbook-cloud, ci]
status: opinion
updated: 2026-10-28
sources: []
links: [ds-widgetbook-cloud, ds-widgetbook-cloud-multi-snapshot, ds-widgetbook-testing, test-golden-alchemist]
---
# ADR-0006 — Catalogue publié et revu sans Widgetbook Cloud

- **Statut :** acceptée le 2026-10-28.
- **Décideur :** porteur du projet (« Je ne l'utiliserais pas »). Cela rejoint la recommandation de l'assistant, qui était de ne pas l'utiliser au départ.
- **Portée :** générique.

## Contexte
Widgetbook Cloud est un SaaS facturé au snapshot. Il offre la revue visuelle par PR, les revues Figma et les multi-snapshots [[ds-widgetbook-cloud]].

## Décision
- Pas d'abonnement à Widgetbook Cloud, ni d'annotation `cloud*` (`cloudAddonsConfigs`, `cloudKnobsConfigs`, `cloudExclude`) dans le code.
- La **non-régression visuelle** passe par des goldens locaux en CI, d'abord alchemist [[test-golden-alchemist]] ; voir [[ds-widgetbook-testing]].
- Le **catalogue** est publié en build web statique. L'hébergement et les previews de PR sont précisés dans [[ds-widgetbook-publish-web]].

## Conséquences
- Pas de revue Figma : l'outil de design est Claude Design ([[adr-0007-ds-design-tool-claude-design]]).
- Les notes [[ds-widgetbook-cloud]] et [[ds-widgetbook-cloud-multi-snapshot]] servent de référence uniquement.

## Quand réexaminer
Si une équipe design externe doit approuver les PR visuellement.

## Historique
- 2026-10-28 — portée précisée lors du nettoyage de knowledge/ (porteur).
