---
id: ds-material-ui-decoupling
title: Flutter 3.47 — Material et Cupertino sortent du framework
tags: [material-ui, cupertino-ui, flutter-3-47, migration, material-3-expressive]
status: verified
updated: 2026-10-27
sources: [https://docs.flutter.dev/release/breaking-changes/material-ui-and-cupertino-ui, https://flutter.dev/blog/decoupling-material-cupertino]
links: [ds-package-structure, ds-governance-versioning, ds-typography, ds-motion, arch-pub-workspaces]
---
# Depuis Flutter 3.47, Material vit dans `package:material_ui` (opt-in), et M3 Expressive n'est pas encore livré

- Flutter 3.47 publie `material_ui` et `cupertino_ui` en 1.0.0, **opt-in**. Ce sont des copies du code gelé depuis Flutter 3.44.
- Migration : `dart fix --apply --code=migrate_design_widgets`, puis l'import `package:material_ui/material_ui.dart`.
- Il faut parfois ajouter le paquet à la main : `flutter pub add material_ui`.
- La **dépréciation formelle** des bibliothèques intégrées au framework est prévue dans une prochaine version stable, sans numéro annoncé.
- Étant un paquet pub, `material_ui` peut évoluer hors du cycle du framework (déduction, voir Pièges pour la version courante).

```yaml
# packages/shared/design_system/pubspec.yaml
dependencies:
  flutter: {sdk: flutter}
  material_ui: ^1.0.0 # contrainte à relever selon la version courante sur pub.dev
```

## M3 Expressive
Le billet officiel du 2026-09-09 dit seulement que des implémentations officielles de Material 3 Expressive (et de Liquid Glass) sont **en cours**, avec des auteurs de paquets de la communauté. Rien n'est livré, et le billet ne précise pas le canal de livraison.

## Conséquences pour le DS (opinion)
- Le package design system dépend **explicitement** de `material_ui` et l'importe ; plus d'import implicite de `package:flutter/material.dart` dans le DS.
- Épingler la version dans le workspace ([[arch-pub-workspaces]]) et traiter chaque montée comme un changement à vérifier (goldens, Widgetbook) : les composants ne suivent plus la version de Flutter.
- **Ne pas viser M3 Expressive maintenant** : rester sur M3 baseline (tokens, easing + durée) et isoler les choix derrière les tokens du DS, pour migrer quand l'implémentation officielle sortira.

## ⚠️ Pièges
- Ne pas mélanger `package:flutter/material.dart` et `package:material_ui/material_ui.dart` dans un même package : lancer le `dart fix` sur tout le workspace.
- Non vérifié par les sources de cette note : `material_ui` en 1.8.0 sur pub.dev au 2026-10-20 (relevé via l'API pub.dev, à revérifier).
- Non vérifié : l'origine exacte (via `material_ui` ou non) de la future livraison Expressive, et les paquets tiers Expressive (source secondaire uniquement).
