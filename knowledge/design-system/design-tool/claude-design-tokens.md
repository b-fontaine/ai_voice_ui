---
id: ds-claude-design-tokens
title: Claude Design — format tokens.json d'un design system (pas du DTCG)
tags: [claude-design, design-tokens, dtcg, style-dictionary, design-system]
status: sourced
updated: 2026-10-28
sources: [https://claude.ai/artifact/5M7UeXXcx16TP3vzVFNDzd, https://support.claude.com/en/articles/14604397-set-up-your-design-system-in-claude-design]
links: [ds-tokens-dtcg-format, ds-tokens-style-dictionary, adr-0005-ds-tokens-style-dictionary, ds-claude-design-overview, ds-claude-design-workflow]
---
# Le tokens.json de Claude Design est un format propriétaire en listes, incompatible avec le DTCG

Un artifact « Design System » stocke ses tokens dans `project/tokens.json`, réécrit en entier à chaque modification. L'index du système est `project/design-system.json`. `tokens.css` et `manifest.json` sont générés par la page (ainsi que les cartes `api/…`) ; un nettoyage ou `/design-sync` peut écrire le premier `tokens.css`. Constat du 2026-10-28.

## Format
```json
{ "color":   { "tokens": [
    { "name": "surface", "value": { "light": "#FFFFFF", "dark": "#121212" }, "usage": "Fond" },
    { "name": "background", "value": "{surface}", "usage": "Alias vers un token existant" } ] },
  "spacing": { "tokens": [ { "name": "md", "value": "16px", "usage": "Gouttière" } ] } }
```
- Chaque famille (`color`, `spacing`, `radius`, `shadow`…) est une **liste** `{"tokens":[{name, value, usage}]}`.
- Multi-thèmes : `value: {"light": …, "dark": …}`. Une valeur chaîne simple vaut pour le premier thème.
- La famille `type` (typographie) a sa propre forme.
- Une map DTCG (`$value`) est illisible : la famille apparaît **vide**.

## Contraintes
- Nom : `[A-Za-z0-9][A-Za-z0-9_.-]{0,63}`, sans `/` ni espace ; unique dans toutes les familles sauf `type`.
- Alias : `"{other-token}"`, vers un token couleur existant. Un alias vers un token absent, ou vers lui-même, est ignoré.
- `var()`, `color-mix()` et couleurs nommées sont **rejetés silencieusement** (supprimés, pas d'erreur).

## Previews
Les previews de composants sont des HTML exécutés dans le navigateur. Ils préchargent `tokens.css`, les polices, `bundle.css`, le bundle et les bibliothèques listées dans l'index. React 18 (jsDelivr) n'est chargé que s'il est listé, comme dans l'exemple par défaut ; sans bibliothèque, previews statiques. Rendu web, jamais Flutter.

Le centre d'aide indique que Claude extrait d'un design system palette, typographie, composants et layout (espacements, grilles, structures de page).

## Conséquence (opinion)
Aucun export DTCG n'est documenté. Le DTCG du dépôt reste la source de vérité ([[adr-0005-ds-tokens-style-dictionary]]) ; un **format Style Dictionary custom** produit `tokens.json` comme second format de sortie, à côté du Dart ([[ds-tokens-style-dictionary]]). Le sens inverse (tokens.json → DTCG) ne sert qu'en import ponctuel.

## ⚠️ Pièges
- Noms DTCG imbriqués (`color.surface.default`) : aplatir avec `.` ou `-`, jamais `/` (opinion).
- Rejet silencieux : valider la sortie générée (comptage des tokens) en CI (opinion).
- Non vérifié : un téléchargement direct de `tokens.json` depuis l'UI ; la grammaire complète (`format.md`, `from-code.md` du type non lus en détail).
- Source : la référence du type Design System (artifact claude.ai), pas une page de doc publique.
