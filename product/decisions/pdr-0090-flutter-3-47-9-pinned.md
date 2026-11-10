---
id: pdr-0090-flutter-3-47-9-pinned
title: "PDR-0090 — Flutter figé à 3.47.9 (Dart 3.13.7)"
area: decisions
status: validated
updated: 2026-11-09
sources: [pubspec.yaml, pubspec.lock, .github/workflows/ci.yaml, tools/flutter-upgrade.sh, knowledge:test-bloc-test, knowledge:di-setup-versions]
links: [pdr-0046-flutter-3-47-8-pinned, pdr-0010-pinned-experimental-versions, pdr-0018-a2ui-v09-genui-0-10-4, pdr-0031-github-actions-ci-linux, p-ar-stack, p-fn-nfr, p-rm-open-questions, test-bloc-test, di-setup-versions, adr-0008-ds-widgetbook-4-beta]
tags: [pdr, decision, versions, flutter, reproducibility]
decision_status: acceptée
decided_on: 2026-11-09
decided_by: "Benoît FONTAINE (porteur), conversation avec l'assistant du 2026-11-09"
scope: technique
supersedes: [pdr-0046-flutter-3-47-8-pinned]
superseded_by: null
---
# PDR-0090 — Flutter figé à 3.47.9

> **En bref.** Le porteur a mis à jour son Flutter local et demande d'aligner le projet. La version figée passe de 3.47.8 à **3.47.9** (correctif ; Dart reste **3.13.7**). Remplace [pdr-0046](pdr-0046-flutter-3-47-8-pinned.md). La CI lit désormais la version dans le `pubspec.yaml` racine, et `tools/flutter-upgrade.sh` (`task upgrade`) automatise la montée.

Part de l'assistant : exécution et vérification de la demande du porteur ; mise en forme de la décision.

## Contexte
- [pdr-0046](pdr-0046-flutter-3-47-8-pinned.md) figeait Flutter 3.47.8 par une contrainte exacte (`environment: flutter:`) dans chaque `pubspec.yaml`. Avec un SDK local en 3.47.9, `flutter pub get` échoue : le dépôt et la machine de démo ([pdr-0028](pdr-0028-linux-demo-machine.md)) ne peuvent plus diverger.
- [pdr-0010](pdr-0010-pinned-experimental-versions.md) et NFR-10 : versions figées, `pubspec.lock` committé ; une montée de Flutter passe par une PR dédiée suivie d'une répétition.
- Demande du porteur (2026-11-09) : « J'ai mis à jour ma version locale de Flutter. Tu peux mettre à jour le projets et ses dépendances et vérifier que tout va bien ? Et n'oublies pas la CI. »

## Hypothèses
- ✅ Sous Flutter 3.47.9, le SDK épingle toujours `test_api` 0.7.12 : les contraintes de résolution connues restent vraies (`build_runner` plafonné à 2.16.1, `bloc_test` inutilisable) — [test-bloc-test], [di-setup-versions], revérifiés le 2026-11-09 par `flutter pub outdated`.
- ⚠️ Hypothèse non confirmée : la démo au micro se comporte comme sous 3.47.8 (voix, WebRTC, rendu). Seule une répétition complète par le porteur le confirme ; les contrôles automatiques ne couvrent ni le micro ni le fournisseur.

## Options
1. **Aligner le dépôt sur 3.47.9** (retenue, demande du porteur)
2. Revenir à 3.47.8 sur la machine de démo

## Décision
- Flutter **3.47.9** (Dart **3.13.7**) est la version figée du produit, déclarée dans le `pubspec.yaml` racine, celui de chaque paquet du workspace, et `pubspec.lock`.
- La CI n'a plus de numéro de version propre : `flutter-version-file: pubspec.yaml`, plus un contrôle `tools/flutter-upgrade.sh --check` (tous les paquets et le lock alignés).
- Les dépendances directes restent figées à la main : `genui` 0.10.4 ([pdr-0018](pdr-0018-a2ui-v09-genui-0-10-4.md)), Widgetbook 4.0.0-beta.14 ([adr-0008-ds-widgetbook-4-beta]). Seules quatre dépendances transitives montent (`code_assets` 2.2.0, `jni` 1.1.2, `objective_c` 9.6.3, `synchronized` 3.6.1+1).
- La politique de pdr-0046 est conservée : toute montée de Flutter passe par une PR dédiée, une nouvelle PDR et une répétition complète.

## Raisons
- La machine du porteur est la machine de démo : le dépôt doit se construire avec le SDK qui y est installé.
- 3.47.9 est un correctif de la même branche stable ; Dart ne change pas.
- Une seule source pour la version (le `pubspec.yaml`) évite un écart entre la CI et le dépôt à la prochaine montée.

## Options écartées
- Revenir à 3.47.8 en local : contraire à la demande du porteur.
- Monter aussi Widgetbook (beta.15 se résout) ou `a2ui_core` : hors de la demande, et ces versions relèvent de décisions existantes ([adr-0008-ds-widgetbook-4-beta], [pdr-0018](pdr-0018-a2ui-v09-genui-0-10-4.md)) ; risque inutile à trois jours du talk.

## Conséquences
- [p-ar-stack](../architecture/stack.md) : Flutter 3.47.9 / Dart 3.13.7.
- NFR-10 ([p-fn-nfr](../functional/nfr.md)) inchangée ; la preuve du build propre reste la CI ([pdr-0031](pdr-0031-github-actions-ci-linux.md)).
- [p-rm-open-questions](../roadmap/open-questions.md) : Q-25 renvoie à cette PDR.
- Le worktree de la boucle (`../ai_voice_ui-loop`, branche `loop`) reste en 3.47.8 tant qu'il n'a pas repris `main` : `pub get` y échoue avec le SDK 3.47.9.
- Les relevés datés qui citent 3.47.8 (spikes, notes `knowledge/`, PDR antérieures) restent tels quels : ils décrivent ce qui a été observé à leur date.

## Réexaminer si
- La répétition révèle une régression propre à 3.47.9 ;
- `genui` ou `flutter_webrtc` exige une autre version de Flutter.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-11-09 | Acceptée ; remplace pdr-0046. Parole du porteur (conversation avec l'assistant, 2026-11-09) : « J'ai mis à jour ma version locale de Flutter. Tu peux mettre à jour le projets et ses dépendances et vérifier que tout va bien ? Et n'oublies pas la CI. » | Benoît FONTAINE (porteur), conversation |

Pas d'archive brute.
