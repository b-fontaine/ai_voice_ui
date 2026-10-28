---
id: ds-claude-design-workflow
title: Chaîne Claude Design ↔ DS Flutter — DTCG source, Claude Design pour la maquette
tags: [claude-design, workflow, design-tokens, handoff, flutter, design-system]
status: opinion
updated: 2026-10-28
sources: [https://claude.com/product/design, https://support.claude.com/en/articles/14604397-set-up-your-design-system-in-claude-design, https://code.claude.com/docs/en/commands.md, https://wmedia.es/en/tips/claude-code-design-sync-your-components, https://code.claude.com/docs/en/artifacts.md]
links: [adr-0007-ds-design-tool-claude-design, ds-claude-design-tokens, adr-0005-ds-tokens-style-dictionary, ds-tokens-theme-extension, ds-widgetbook-4-setup]
---
# Claude Design sert à la maquette ; le dépôt Git reste la source du design system Flutter

Constat du 2026-10-28 : aucune source officielle ne mentionne Flutter ni un export Dart. Les rendus documentés sont tous web (HTML, previews React). D'où une chaîne à sens unique, code → design (décision du porteur, adr-0007).

## Faits
- `/design-sync` (skill intégrée à Claude Code) convertit le design system **React** d'un dépôt et l'envoie au site autonome `claude.ai/design`. Connexion claude.ai requise (`/design-login`) ; indisponible sur Bedrock, Google Cloud Agent Platform, Microsoft Foundry, Claude Platform on AWS et via un gateway Claude apps. Première synchro : plusieurs heures.
- Le centre d'aide le recommande quand le système existe déjà en composants React et cite d'autres voies (chat, uploads). La page produit : « fonctionne le mieux » pour un design system React ; aucun autre framework cité.
- Source tierce (wmedia) : seulement un package React avec `dist/` publié, ou un Storybook ; ni Vue, ni Angular, ni Svelte.
- La doc artifacts de Claude Code conseille de consigner les tokens (couleurs, typo, espacements) dans `CLAUDE.md` ou un fichier de thème du dépôt : la skill de design les lit en priorité.

## Chaîne recommandée (opinion)
1. **DTCG dans Git**, source de vérité ([[adr-0005-ds-tokens-style-dictionary]]).
2. **Style Dictionary** génère (a) le Dart / `ThemeExtension` ([[ds-tokens-theme-extension]]) et (b) le `tokens.json` Claude Design ([[ds-claude-design-tokens]]).
3. Ce `tokens.json` alimente un **artifact design system** dans Claude.
4. Maquettes et prototypes des écrans et des surfaces GenUI dans Claude Design.
5. **Handoff** vers Claude Code (« Send to local coding agent ») ; implémentation en widgets `Ds*` Flutter, vérifiés dans Widgetbook ([[ds-widgetbook-4-setup]]).
6. Consigner aussi les tokens dans `CLAUDE.md` ou un fichier de thème, pour `/design` et la skill de design.

**Ne pas utiliser `/design-sync`** pour le DS Flutter : il ne sait lire que du React.

## Décision et points ouverts
- Sens de synchronisation **code → design** uniquement ; les retouches de tokens faites dans Claude Design sont reportées à la main dans le DTCG. **Confirmé par le porteur le 2026-10-28** ([[adr-0007-ds-design-tool-claude-design]]).
- Sort de `/design-sync` après le 2026-12-14 : la doc dit qu'il vise le site autonome ; aucun remplacement annoncé (non vérifié).

## ⚠️ Pièges
- Le handoff produit du code web (contenu exact non vérifié) : c'est une spécification visuelle, pas du code à copier.
