---
id: ds-tokens-dtcg-format
title: Format DTCG 2025.10 — règles normatives des design tokens
tags: [design-tokens, dtcg, w3c, design-system]
status: verified
updated: 2026-10-27
sources: [https://www.w3.org/community/reports/design-tokens/CG-FINAL-format-20251028/, https://www.w3.org/community/design-tokens/2025/10/28/design-tokens-specification-reaches-first-stable-version/]
links: [ds-tokens-dtcg-theming, ds-tokens-theme-extension, ds-tokens-style-dictionary]
---
# DTCG 2025.10 : le format pivot des tokens

Le *Design Tokens Format Module* **2025.10** est la première version stable. Il a été publié le **2025-10-28** comme *Final Community Group Report* du W3C. Ce n'est **ni un standard W3C ni un texte sur la voie de la standardisation**.

## Fichiers
Extension `.tokens` ou `.tokens.json`. Type média `application/design-tokens+json` (`application/json` est accepté).

## Règles normatives
- Un objet est un token **si et seulement s'il a `$value`**, la seule propriété obligatoire.
- `$type` est optionnel et **s'hérite** du groupe parent le plus proche. Les outils **ne doivent pas** deviner le type d'après la valeur : un token dont le type est indéterminable est invalide.
- **7 types simples :** `color`, `dimension`, `fontFamily`, `fontWeight`, `duration`, `cubicBezier`, `number`.
- **6 types composites :** `strokeStyle`, `border`, `transition`, `shadow`, `gradient`, `typography`.
- `dimension` est un objet `{value, unit}` avec `unit` = `px` ou `rem`. L'unité est requise même pour 0.
- `color` est un objet `{colorSpace, components, alpha?, hex?}`. Display P3, OKLCH et les espaces de CSS Color 4 sont pris en charge.
- **Alias :** `{group.token}` pointe vers un token entier. `$ref` (JSON Pointer) vise une partie d'une valeur. `$extends` fait hériter un groupe d'un autre. Une référence circulaire est une erreur.

```json
{
  "color": {
    "$type": "color",
    "brand": { "500": { "$value": { "colorSpace": "oklch", "components": [0.62, 0.17, 255] } } },
    "action": { "primary": { "$value": "{color.brand.500}" } }
  },
  "space": { "$type": "dimension", "2": { "$value": { "value": 8, "unit": "px" } } }
}
```

## ⚠️ Pièges
- L'exemple 12 de la spec utilise `$type: string`, absent de la liste normative. Ne pas s'en servir.
- Le texte parle de « Candidate Recommendation » alors que l'en-tête dit « Final CG Report ». C'est l'en-tête qui fait foi.
