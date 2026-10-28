---
id: ux-genui-catalog-as-ds
title: Le catalogue A2UI est le reflet du design system
tags: [genui, a2ui, catalog, design-system, theming]
status: verified
updated: 2026-10-28
sources: [https://a2ui.org/concepts/catalogs/, https://a2ui.org/guides/theming/, https://a2ui.org/specification/v0.9.1-a2ui/, https://docs.flutter.dev/ai/genui/get-started, https://docs.flutter.dev/ai/genui/components]
links: [genui-custom-catalog-item, genui-catalog-ids, ds-component-api, ds-widgetbook-4-genui, ds-governance-versioning]
---
# En production, le catalogue A2UI reflète directement le design system

a2ui.org recommande qu'une app de production définisse **son propre catalogue**, qui reflète son design system, plutôt que d'adapter le Basic Catalog au DS. On peut toutefois importer certaines définitions du Basic Catalog dans son catalogue.

- **genui :** `BasicCatalogItems` (texte, markdown, images) sert à démarrer. La doc recommande un catalogue sur mesure en production. API des items : [[genui-custom-catalog-item]].
- **Thème :** le style des surfaces est contrôlé par le renderer, et le thème relève de l'implémentation du catalogue. L'agent n'envoie que des **indications sémantiques**, jamais de styles visuels.
- **Nom de l'indication :** le guide de theming dit encore `usageHint` (terme v0.8). En v0.9.1, le composant `Text` porte `variant` (`h2`, `caption`…). Le principe reste le même.
- **Builders genui :** la doc ne montre aucune API de thème dédiée. L'exemple `RiddleCard` lit `Theme.of(context)` avec `context = itemContext.buildContext`.
- **Négociation :** le client envoie `supportedCatalogIds` ; l'agent fige un catalogue pour la vie de la surface ([[genui-catalog-ids]]).

## Versionner le catalogue comme une API
- Ajouter un composant est sans risque.
- On ne supprime pas : `deprecated: true` + `x-deprecated-reason`, et le renderer garde le support.
- Un changement cassant donne une **version majeure dans l'URI du `catalogId`** (v1 → v2). Pendant la migration, le client annonce v1 et v2.

## Règles du projet (opinion)
- Chaque `CatalogItem` **enveloppe un composant `Ds*`** du design system : il ne crée pas de style, il lit `ThemeData` et les `ThemeExtension` du DS via `itemContext.buildContext`.
- Un item = une story Widgetbook v4 (`Meta(DsX.new)`), plus une surface A2UI en cache rejouée via `CachedSurface` ([[ds-widgetbook-4-genui]]).
- Les `variant` exposés au LLM correspondent aux variantes nommées du composant DS ([[ds-component-api]]).
- Rédiger les `description` du schéma pour le LLM (quoi, quand). Que le LLM les lise est une **inférence** : le schéma est injecté dans le prompt, la doc ne le dit pas explicitement.
- Le catalogue suit le même rythme de versionnage que le package DS ([[ds-governance-versioning]]).

## ⚠️ Pièges
- Les composants du Basic Catalog **ignorent le `theme`** envoyé par l'agent dans `createSurface` : ne pas compter dessus pour habiller l'UI.
- Le DESIGN.md de genui n'a pas pu être lu (404) : une API de thème dédiée aux surfaces reste **non vérifiée**.
- Version A2UI réellement implémentée par genui 0.10.4 (noms v0.8 dans la doc Flutter, v0.9.1 dans la spec) : non vérifié au 2026-10-27.
