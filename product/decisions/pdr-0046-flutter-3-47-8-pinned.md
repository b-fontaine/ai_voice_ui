---
id: pdr-0046-flutter-3-47-8-pinned
title: "PDR-0046 — Flutter figé à 3.47.8 (Dart 3.13.7)"
area: decisions
status: validated
updated: 2026-10-29
sources: [specs/000-loop-harness/status.md, pubspec.yaml, pubspec.lock, knowledge:ds-widgetbook-4-spike]
links: [p-rm-open-questions, p-ar-stack, p-rm-roadmap, p-rm-spikes, p-fn-nfr, pdr-0010-pinned-experimental-versions, pdr-0018-a2ui-v09-genui-0-10-4, ds-widgetbook-4-spike, perf-desktop-specifics, genui-overview]
tags: [pdr, decision, versions, flutter, reproducibility]
decision_status: acceptée
decided_on: 2026-10-29
decided_by: "Benoît FONTAINE (porteur), conversation avec l'assistant du 2026-10-29"
scope: technique
supersedes: []
superseded_by: null
---
# PDR-0046 — Flutter figé à 3.47.8

> **En bref.** Tranche Q-25. La version de Flutter figée pour Genesis Canvas est **3.47.8** (Dart 3.13.7), déjà figée par la fonctionnalité 000 (`environment: flutter: 3.47.8` dans `pubspec.yaml`, `sdks.flutter: "3.47.8"` dans `pubspec.lock`). Précise [pdr-0010](pdr-0010-pinned-experimental-versions.md), qui imposait le gel sans fixer la version.

Part de l'assistant : recommandation acceptée par le porteur.

## Contexte
- [pdr-0010](pdr-0010-pinned-experimental-versions.md) et NFR-10 (fiche § 5) : Flutter figé, `pubspec.lock` committé, build propre sur machine vierge ; la version exacte restait ouverte (Q-25, [p-rm-open-questions](../roadmap/open-questions.md)).
- Le spike Widgetbook est validé sous Flutter 3.47.8 / Dart 3.13.7 ([ds-widgetbook-4-spike]) ; SP-10 (rendu `genui` 0.10.4 sous Linux) et SP-03 ont été exécutés sous cette version ([genui-overview], `specs/001-sp-03-a2a-go-genui/notes-s3.md`).
- La fonctionnalité 000 a figé 3.47.8 dans `pubspec.yaml` (`environment: flutter: 3.47.8`, `sdk: 3.13.7`) et `pubspec.lock` (`sdks.flutter: "3.47.8"`).

## Hypothèses
- ✅ Flutter 3.47.8 fonctionne avec `genui` 0.10.4, `flutter_webrtc` 1.6.3 et Widgetbook 4.0.0-beta.14 sur la machine Linux de démo (SP-10, spike Widgetbook, [pdr-0028](pdr-0028-linux-demo-machine.md)).

## Options
1. **3.47.8, déjà validée par le spike et figée par 000** (retenue)
2. Une version plus récente après SP-01

## Décision
- Flutter **3.47.8** (Dart **3.13.7**) est la version figée du produit ; elle reste déclarée dans `pubspec.yaml` et `pubspec.lock`.
- Toute montée de Flutter passe par une PR dédiée suivie d'une répétition complète ([pdr-0010](pdr-0010-pinned-experimental-versions.md), politique d'épinglage).

## Raisons
- Version déjà exercée par tous les essais du projet (SP-10, SP-03, spike Widgetbook) et figée dans le dépôt ; aucune contre-indication relevée par SP-01.
- Une version plus récente n'apporte rien à la démo et ajoute un risque à 14 jours du talk.

## Options écartées
- Version plus récente : aucun bénéfice documenté pour la démo ; risque de régression sur `genui`, Widgetbook et `flutter_webrtc` ([pdr-0010](pdr-0010-pinned-experimental-versions.md)).

## Conséquences
- [p-ar-stack](../architecture/stack.md) : Flutter 3.47.8 / Dart 3.13.7 passent de « à figer » à « figé ».
- [p-rm-roadmap](../roadmap/roadmap.md) : Q-25 levée pour J2 ; [p-rm-open-questions](../roadmap/open-questions.md) : Q-25 tranchée → pdr-0046.

## Réexaminer si
- Un bogue bloquant de Flutter 3.47.8 touche la démo sans contournement ;
- `genui` ou `flutter_webrtc` exige une version de Flutter plus récente.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-29 | Acceptée ; Q-25 tranchée (Flutter 3.47.8). Parole du porteur (conversation avec l'assistant, 2026-10-29), en réponse au tableau des questions présenté juste avant : « Pour les questions, utilise tes recommandations » | Benoît FONTAINE (porteur), conversation |

Pas d'archive brute.
