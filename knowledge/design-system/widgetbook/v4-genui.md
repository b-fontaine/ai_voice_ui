---
id: ds-widgetbook-4-genui
title: Widgetbook 4.0 bêta — cataloguer et tester un catalogue GenUI
tags: [widgetbook, genui, a2ui, catalog, testing, design-system]
status: verified
updated: 2026-10-28
sources: [https://github.com/widgetbook/widgetbook/blob/v4/docs/genui/overview.mdx, https://docs.widgetbook.io/~v4/genui/overview, https://docs.widgetbook.io/~v4/genui/testing]
links: [ux-genui-catalog-as-ds, genui-test-catalog-items, genui-custom-catalog-item, ds-widgetbook-4-testing, adr-0008-ds-widgetbook-4-beta]
---
# Widgetbook v4 documente le catalogue GenUI, sans API spécifique

La doc v4 a une section GenUI (pages overview, catalog et testing), ajoutée le 2026-08-08 (PR #2006). Elle le dit elle-même : « Widgetbook has no GenUI-specific API. » Tout repose sur les stories, args, scénarios et modes habituels. Information datée du 2026-10-28.

## Correspondance officielle
| Flutter GenUI SDK | Widgetbook v4 |
|---|---|
| `CatalogItem.name` | Component |
| `dataSchema` | Args typés |
| `widgetBuilder` | widget rendu par la story |

## Recommandations de la doc (pages catalog et testing)
- Séparer le **widget présentationnel** du binding `CatalogItem` : la story catalogue le widget ([[genui-custom-catalog-item]]).
- Remplacer le `DataModel` par un **widget hôte stateful** dans la story.
- **Rejouer des surfaces A2UI mises en cache**, avec un `_Scenario` par payload : un widget `CachedSurface({required A2uiMessage payload})` est catalogué avec `Meta(CachedSurface.new)` et `Arg.fixed(cachedSurfaces.first)`.
- Les violations d'accessibilité de chaque scénario sont écrites dans `build/.widgetbook/<Component>/<Story>/<Scenario>.json`.
- Le diff des snapshots et des régressions a11y par rapport à la branche de base est réservé à la publication sur Widgetbook Cloud.

## Usage dans la démo du talk (opinion)
- Le catalogue GenUI **est** le design system ([[ux-genui-catalog-as-ds]]) : une story par `CatalogItem`, avec des args alignés sur le `dataSchema`. C'est la démonstration visible du talk ([[adr-0008-ds-widgetbook-4-beta]]).
- Enregistrer quelques messages A2UI réels (fixtures JSON versionnées) et les rejouer via `CachedSurface`, un scénario par payload. Pas d'appel réseau ni de LLM dans le catalogue.
- Sans Cloud ([[adr-0006-ds-no-widgetbook-cloud]]) : les violations a11y du JSON servent de gate maison, et les goldens restent dans alchemist ([[ds-widgetbook-4-testing]]).
- Les tests unitaires des `CatalogItem` (schéma, parsing) restent dans la suite GenUI ([[genui-test-catalog-items]]). Widgetbook couvre le rendu.

## ⚠️ Pièges
- `CachedSurface` est le widget **de l'exemple de la doc**. Non vérifié : qu'il soit fourni par un package. Il est à écrire soi-même.
- La version de `genui` visée par les pages Widgetbook n'est pas précisée dans la source (non vérifié). Vérifier `A2uiMessage` contre la version utilisée ([[genui-custom-catalog-item]]).
