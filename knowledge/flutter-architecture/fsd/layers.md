---
id: arch-fsd-layers
title: Feature-Sliced Design — couches et règle d'import descendante
tags: [fsd, architecture, layers, imports]
status: verified
updated: 2026-10-26
sources: [https://feature-sliced.design/docs/reference/layers, https://feature-sliced.design/docs/get-started/overview]
links: [arch-fsd-slices-segments, arch-fsd-public-api, arch-fsd-pages-first, arch-fsd-dart-mapping, arch-clean-dependency-rule]
---
# 7 couches standardisées (FSD v2.1, doc consultée le 2026-10-26)

Les couches sont listées du haut (le plus de responsabilités et de dépendances) vers le bas.

| Couche | Rôle | Slices ? |
|---|---|---|
| `app` | entrypoints, routing, providers, styles globaux | non (segments) |
| `processes` | **dépréciée**, ancienne place des scénarios multi-pages | — |
| `pages` | écrans entiers ou grandes parties d'écran | oui |
| `widgets` | gros blocs d'UI autonomes, réutilisés entre pages | oui |
| `features` | interactions utilisateur qui apportent de la valeur | oui |
| `entities` | concepts métier (User, Post…) | oui |
| `shared` | UI kit, libs, clients API, config. **Sans métier** | non (segments) |

**Règle d'import :**
- « Un module d'une slice ne peut importer d'autres slices que si elles sont sur des couches **strictement inférieures**. »
- `app` et `shared` font exception : leurs segments s'importent librement entre eux.
- Pour `processes`, la spec dit d'éviter cette couche et de répartir son contenu entre `features` et `app`.

**Quand l'adopter :** pour des applications (pas des librairies), avec n'importe quelle taille d'équipe. La doc ajoute : « si l'architecture actuelle marche, ce n'est peut-être pas la peine de changer ».

⚠️ Pièges
- FSD est pensé pour le front JS/TS. Le linter officiel Steiger ne cible pas Dart, il faut un outillage équivalent (`arch-import-lint`).
- Toutes les couches ne sont pas obligatoires : n'utiliser que celles qui servent.
