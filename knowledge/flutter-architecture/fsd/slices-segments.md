---
id: arch-fsd-slices-segments
title: FSD — slices (métier) et segments (technique)
tags: [fsd, slices, segments, cohesion]
status: verified
updated: 2026-10-28
sources: [https://feature-sliced.design/docs/reference/slices-segments]
links: [arch-fsd-layers, arch-fsd-public-api, arch-fsd-dart-mapping, bloc-no-cubit]
---
# Slices = découpage métier ; segments = découpage technique

**Slices**, le 2ᵉ niveau : elles regroupent le code par **sens produit**, par exemple `voice-session`, `genui-surface` ou `user`.
- Leurs noms viennent du domaine, pas de la technique.
- Des slices d'une même couche **ne s'importent pas entre elles** : couplage nul, forte cohésion.
- On peut regrouper des slices proches dans un dossier, mais ce dossier ne doit pas contenir de code partagé.

**Segments**, le 3ᵉ niveau : ils regroupent le code par **rôle technique**.

| Segment | Contenu FSD | Équivalent Clean/Flutter (opinion) |
|---|---|---|
| `ui` | composants, formatters, styles | presentation (widgets, pages) |
| `model` | schémas, stores, logique métier | domain + state (entities, Bloc — Cubit exclu, [[bloc-no-cubit]] —, use-cases) |
| `api` | requêtes backend, types, mappers | data (services, DTO, mappers, repo impl) |
| `lib` | helpers internes à la slice | utils privés |
| `config` | configuration, feature flags | config, constantes |

La doc conseille des noms de segments qui décrivent le **but**, pas la nature. `components`, `hooks` et `types` sont des contre-exemples.

⚠️ Pièges
- En Dart, `model` mélange l'état UI et le domaine. On peut subdiviser `model/` en `model/domain` et `model/state` pour garder la règle Clean (`arch-clean-fsd-combo`).
