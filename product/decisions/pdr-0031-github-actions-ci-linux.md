---
id: pdr-0031-github-actions-ci-linux
title: "PDR-0031 — CI GitHub Actions (build et tests Linux) mise en place pour la montrer ; la démo tourne en debug sur le poste"
area: decisions
status: validated
updated: 2026-10-29
sources: [conversation porteur 2026-10-29, product/sources/product-description.pdf#p7, knowledge:test-coverage-ci]
links: [p-ar-quality, p-fn-nfr, p-rm-open-questions, p-rm-backlog, pdr-0010-pinned-experimental-versions, pdr-0028-linux-demo-machine, pdr-0029-local-docker-compose-hosting, test-coverage-ci]
tags: [pdr, decision, ci, github-actions, linux]
decision_status: acceptée
decided_on: 2026-10-29
decided_by: "Benoît FONTAINE (porteur), conversation avec l'assistant du 2026-10-29 ; parties contraintes (GitHub Actions, Linux) : Assistant (décision contrainte), sur délégation du porteur du 2026-10-29"
constraint_basis: [pdr-0028-linux-demo-machine, pdr-0029-local-docker-compose-hosting]
scope: technique
supersedes: []
superseded_by: null
---
# PDR-0031 — CI GitHub Actions, build Linux

> **En bref.** Une CI est mise en place **pour la montrer**. Elle tourne sur **GitHub Actions** et construit et teste l'app pour **Linux** ainsi que le backend Go. La démo, elle, tourne en debug sur le poste du porteur. NFR-10 est conservé. Tranche Q-56.

Part de l'assistant : consignation de l'arbitrage du porteur (CI oui, démo en debug) ; choix de GitHub Actions et de Linux par contrainte (voir ci-dessous).

## Contexte
- Q-56 : quelle plateforme de CI pour le build macOS (et Windows) ? La cible est désormais Linux ([pdr-0028](pdr-0028-linux-demo-machine.md)).
- NFR-10 : build propre sur machine vierge depuis le `pubspec.lock` ([pdr-0010](pdr-0010-pinned-experimental-versions.md)).

## Hypothèses
- ✅ Le dépôt est hébergé sur GitHub (`github.com/b-fontaine/ai_voice_ui`).

## Options
1. **GitHub Actions, runners Linux** (retenue)
2. Pas de CI

## Décision
- CI GitHub Actions : analyse, `build_runner` + `git diff --exit-code`, tests (unit, bloc, widget, BDD), `testWidgetbook` + goldens, `go test -race`, et build **Linux** depuis le lockfile ([p-ar-quality](../architecture/quality.md)).
- La démo n'est **pas** lancée depuis un artefact de CI : elle tourne en debug sur le poste ([pdr-0029](pdr-0029-local-docker-compose-hosting.md)).
- NFR-10 est conservé ; le job « clean build » de la CI sert de preuve de build sur machine vierge.

## Parties contraintes
- **GitHub Actions** : l'app Flutter vit dans ce dépôt, hébergé sur GitHub, dont c'est la CI intégrée ; aucune autre CI n'est rattachée à ce dépôt. La CI du backend suit le dépôt qui l'accueillera (Q-27, ouverte) : GitHub Actions si c'est ce dépôt ; l'Azure Pipelines du plan de production ne vaut que pour `septeo_saaster_kit`.
- **Linux** : seule cible de la démo ([pdr-0028](pdr-0028-linux-demo-machine.md)).

## Raisons
- Parole du porteur (2026-10-29) : « Pour la CI, on peut la mettre en place pour montrer mais je pensais lancer le projet en debug sur mon poste. »

## Options écartées
- **Pas de CI** : le porteur veut la montrer.
- **Builds macOS et Windows** : plus des cibles.

## Conséquences
- [p-ar-quality](../architecture/quality.md) : section CI mise à jour.
- [p-rm-open-questions](../roadmap/open-questions.md) : Q-56 tranchée.

## Réexaminer si
- Les runners GitHub ne peuvent pas construire genui sous Linux (dépendances GStreamer : voir SP-10).

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-29 | Acceptée : « Pour la CI, on peut la mettre en place pour montrer mais je pensais lancer le projet en debug sur mon poste. » (conversation) | Benoît FONTAINE (porteur) |
| 2026-10-29 | Revue : parties contraintes (GitHub Actions, Linux) inscrites dans `decided_by` et `constraint_basis` ; CI du backend rattachée à Q-27 (rouverte) | Assistant |

Pas d'archive brute.
