---
id: ds-tokens-figma-sources
title: Tokens depuis Figma — import DTCG, API Enterprise, Tokens Studio
tags: [design-tokens, figma, tokens-studio, dtcg, design-system]
status: verified
updated: 2026-10-28
sources: [https://help.figma.com/hc/en-us/articles/15343816063383-Modes-for-variables, https://developers.figma.com/docs/rest-api/variables/, https://developers.figma.com/docs/plugins/api/Variable/, https://developers.figma.com/docs/code-connect/template-files/, https://docs.tokens.studio/manage-settings/token-format, https://docs.tokens.studio/token-storage/remote/sync-git-github]
links: [ds-tokens-dtcg-format, ds-tokens-style-dictionary, ds-tokens-dtcg-theming, ds-governance-versioning, adr-0007-ds-design-tool-claude-design, ds-claude-design-workflow]
---
# Figma ne parle pas Flutter : le dépôt Git doit rester la source des tokens

> Outil de design retenu par l'ADR : Claude Design, pas Figma ([[adr-0007-ds-design-tool-claude-design]], [[ds-claude-design-workflow]]). Note conservée comme référence.

Au 2026-10-27, ni le `codeSyntax` des variables (Dev Mode) ni Code Connect ne prévoient Flutter. Le lien Figma ↔ code passe par des fichiers JSON.

## Variables Figma : import/export JSON natif
- Figma importe et exporte les **modes de variables** en JSON. Le format **DTCG n'est confirmé que pour l'import** : chaque fichier importé crée un mode.
- Contraintes à l'import : couleurs en **sRGB ou HSL**, dimensions en `px`, durées en `s`, noms imbriqués convertis en chemins `a/b/c`.
- Booléen = token `number` avec `$extensions` `com.figma.type: "boolean"` (0 = false).

## API REST Variables : Enterprise uniquement
- `GET` local variables (scope `file_variables:read`) : tout membre d'une org Enterprise ayant accès en lecture au fichier.
- `POST` variables (scope `file_variables:write`) : siège Full ou rôle admin, plus accès en écriture. Invités exclus.

## Dev Mode et Code Connect
- `codeSyntax` d'une variable (API plugin) : seulement `'WEB'`, `'ANDROID'`, `'iOS'`. **Pas de Flutter.**
- Code Connect : siège Dev ou Full. Les *template files*, agnostiques du framework, sont le format principal ; les parsers React, HTML, SwiftUI, Compose, Web components et Storybook sont « Legacy ». Aucune page ne mentionne Flutter.

## Tokens Studio (plugin Figma)
- Format « legacy » (défaut) ou W3C DTCG (`$value`, `$type`, `$description`), changeable à tout moment avec conversion des JSON. En DTCG, `{`, `}` et `$` sont interdits dans les noms.
- Synchronisation GitHub bidirectionnelle (push/pull). Multi-fichiers (un JSON par Token Set + fichier de thèmes) = fonction **Pro** ; sans licence Pro, accès en lecture seule.

## Recommandation (opinion)
- Source de vérité : des fichiers `.tokens.json` DTCG dans le dépôt Git ([[ds-tokens-dtcg-format]], [[ds-tokens-dtcg-theming]]), transformés par [[ds-tokens-style-dictionary]]. Figma n'est qu'un **client** : il importe ces fichiers, ou pousse via Tokens Studio sous revue de PR ([[ds-governance-versioning]]).
- Pas de dépendance à l'API REST : elle impose Enterprise.
- Question de l'outil de design tranchée : Claude Design, pas Figma ([[adr-0007-ds-design-tool-claude-design]]). Le plan Figma n'est à vérifier que si Figma revient dans la chaîne.

## ⚠️ Pièges
- Non vérifié : la forme de l'export Figma (espace de couleur, alias conservés, descriptions). Aucune page officielle ne la détaille.
- Tokens OKLCH ou Display P3 : hors des espaces acceptés à l'import Figma (sRGB/HSL seulement). Garder un repli `hex` dans les tokens couleur (opinion).
- Code Connect sur plan Professional : la doc développeurs l'inclut (une seule bibliothèque et un seul framework actifs), le centre d'aide et le support parlent d'Organization/Enterprise, et un post de forum du 2026-10-23 signale des mappings refusés sur Professional. Contradiction à vérifier.
- Non vérifié : une valeur `language` Dart pour les template files Code Connect.
