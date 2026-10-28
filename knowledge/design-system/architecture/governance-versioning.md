---
id: ds-governance-versioning
title: Gouvernance et versionnage du design system
tags: [governance, semver, deprecation, changelog, design-system]
status: sourced
updated: 2026-10-27
sources: [https://dart.dev/tools/pub/dependencies, https://dart.dev/tools/pub/versioning, https://api.dart.dev/dart-core/Deprecated-class.html, https://docs.flutter.dev/release/compatibility-policy, https://dart.dev/tools/pub/package-layout, https://bradfrost.com/blog/post/a-design-system-governance-process/]
links: [ds-package-structure, ds-widgetbook-testing, ds-material-ui-decoupling, test-coverage-ci]
---
# Le DS suit le semver Dart, déprécie avant de supprimer, et filtre les nouveaux composants par un processus de gouvernance

## Versionnage Dart
- **Caret** : `^1.2.3` s'arrête à la majeure suivante ; avant 1.0, à la **mineure** suivante (`^0.1.2` = `>=0.1.2 <0.2.0`).
- **Semver pré-1.0 décalé d'un cran** : 0.1.2 → 0.2.0 cassant, 0.1.3 fonctionnalité, 0.1.2+1 sans effet sur l'API. Après 1.0, tout changement incompatible incrémente la majeure.
- **Dépréciation** : `@Deprecated('message de migration')`, le message dit comment obtenir le même effet. Constructeurs ciblés : `Deprecated.extend`, `.implement`, `.instantiate`, `.mixin`, `.optional`, `.subclass`.
- **Politique Flutter** : pas de calendrier fixe de suppression ; une suppression suit la procédure d'un changement cassant (annonce, notes de version, guide de migration).
- **CHANGELOG pub** : une section par version, titres tous au même niveau (tous `#` ou tous `##`), contenant le numéro (préfixe `v` toléré).

```dart
@Deprecated('Utiliser DsButton.tonal. Suppression en 0.5.0.')
const DsButton.secondary({...});
```

## Processus de Brad Frost
1. Utiliser d'abord les composants existants.
2. Contacter tôt l'équipe design system.
3. Classer le besoin : **snowflake** ou composant du système.
4. Prototyper.
5. Revoir le concept initial.
6. Design, développement et tests formels dans une branche.
7. Revue finale avec l'équipe produit.
8. Documenter et préparer.
9. Publier en semver.
10. Les équipes produit adoptent et font leur QA.

Une snowflake (composant ponctuel d'un seul produit) va dans le backlog de l'équipe produit, pas dans le DS.

## Application au projet (opinion)
- Rester en 0.x tant que l'API bouge ; bumper la mineure à chaque changement cassant.
- Nouveau composant : **pas d'ADR**, mais une revue DS (étapes 3 à 7) dans la PR. Un ADR seulement pour un choix technologique (lib de tokens, passage à Expressive).
- Snowflakes : dans la feature FSD qui les utilise ; promotion au DS dès la 2ᵉ réutilisation.
- CI : chaque composant public a au moins un use case Widgetbook et un golden ([[ds-widgetbook-testing]], [[test-coverage-ci]]).
- Déprécier pendant au moins une mineure avant suppression.

## ⚠️ Pièges
- Avec `^0.x`, un consommateur ne reçoit pas les mineures suivantes : chaque 0.x+1 demande une montée explicite.
- Non vérifié : modèles d'équipe de Nathan Curtis (solitary, centralized, federated), source non lue.
