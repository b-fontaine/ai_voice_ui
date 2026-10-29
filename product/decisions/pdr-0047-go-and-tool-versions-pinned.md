---
id: pdr-0047-go-and-tool-versions-pinned
title: "PDR-0047 — Versions hors Flutter : Go 1.27.3 figé au premier commit de code, Style Dictionary à l'introduction, genui reste 0.10.4"
area: decisions
status: validated
updated: 2026-10-29
sources: [specs/001-sp-03-a2a-go-genui/notes-s1.md, specs/001-sp-03-a2a-go-genui/notes-s3.md, knowledge:proto-a2a-go-v03-compat, product/architecture/stack.md]
links: [p-rm-open-questions, p-ar-stack, p-ar-backend, p-rm-roadmap, p-rm-backlog, pdr-0010-pinned-experimental-versions, pdr-0018-a2ui-v09-genui-0-10-4, pdr-0041-backend-in-this-repo-local-no-auth, pdr-0046-flutter-3-47-8-pinned, adr-0003-backend-go, adr-0005-ds-tokens-style-dictionary, proto-a2a-go-v03-compat, ma-backend-sdk-go, genui-overview]
tags: [pdr, decision, versions, go, style-dictionary, genui, reproducibility]
decision_status: acceptée
decided_on: 2026-10-29
decided_by: "Benoît FONTAINE (porteur), conversation avec l'assistant du 2026-10-29"
scope: technique
supersedes: []
superseded_by: null
---
# PDR-0047 — Versions hors Flutter

> **En bref.** Tranche Q-46. **Go** : la toolchain vérifiée, **Go 1.27.3** (qui résout `a2a-go/v2` v2.7.0), est figée dans le `go.mod` du backend au premier commit de code ; le plancher documenté reste ≥ 1.26.10. **Style Dictionary** : version figée quand l'outil est introduit. **genui** : reste 0.10.4, aucune montée sans PR dédiée ([pdr-0010](pdr-0010-pinned-experimental-versions.md)).

Part de l'assistant : recommandation acceptée par le porteur.

## Contexte
- Question Q-46 ([p-rm-open-questions](../roadmap/open-questions.md)) : [pdr-0010](pdr-0010-pinned-experimental-versions.md) ne couvre que les paquets Flutter ; le gel des modules Go (`go.sum`, version de Go) et des outils n'était pas décidé. [p-ar-stack](../architecture/stack.md) disait « Go ≥ 1.26.10 — à figer » et « Style Dictionary 5.7.1 — à figer ».
- SP-03 (2026-10-29) : agent Go de test sous `go 1.27.3` avec `github.com/a2aproject/a2a-go/v2 v2.7.0` ; essai de bout en bout concluant ([proto-a2a-go-v03-compat], `specs/001-sp-03-a2a-go-genui/notes-s1.md`).
- Go ≥ 1.26 est exigé par les SDK agents Go ([adr-0003-backend-go], [ma-backend-sdk-go]). Le backend de démo vit dans ce dépôt, sous `backend/` ([pdr-0041](pdr-0041-backend-in-this-repo-local-no-auth.md)) ; il n'existe pas encore de code Go.
- `genui` 0.10.4 est figé par [pdr-0018](pdr-0018-a2ui-v09-genui-0-10-4.md) ; une version 0.10.6 non publiée est évoquée ([genui-overview]).

## Hypothèses
- ✅ Go 1.27.3 est la toolchain de la machine de démo et résout `a2a-go/v2` v2.7.0 (SP-03).

## Options
1. **Figer au premier commit de code** (retenue) : la version vérifiée pour Go, la version retenue à l'introduction pour Style Dictionary
2. Figer tout dès maintenant, sans code

## Décision
- **Go** : le `go.mod` du backend, créé au premier commit de code Go, porte la toolchain **Go 1.27.3** ; `go.sum` committé. Le plancher documenté (≥ 1.26.10) reste une contrainte minimale, non la version de travail. `a2a-go/v2` : v2.7.0.
- **Style Dictionary** : la version est figée au moment où l'outil est introduit dans le dépôt (version exacte, lockfile committé) ; 5.7.1 est la version relevée le 2026-10-28 ([adr-0005-ds-tokens-style-dictionary]).
- **genui** : reste **0.10.4**. Aucune montée (dont 0.10.6) sans PR dédiée suivie d'une répétition ([pdr-0010](pdr-0010-pinned-experimental-versions.md), [pdr-0018](pdr-0018-a2ui-v09-genui-0-10-4.md)).
- Flutter : voir [pdr-0046](pdr-0046-flutter-3-47-8-pinned.md). LLM texte : Q-17, toujours ouverte.

## Raisons
- Figer au premier commit évite de décider dans le vide et colle à la version réellement exercée (SP-03).
- Un gel déclaré sans code n'est pas vérifiable ; le `go.mod` et le lockfile le deviennent dès le premier commit.

## Options écartées
- Tout figer sans code : aucune vérification possible ; la version de Style Dictionary peut changer d'ici son introduction.

## Conséquences
- [p-ar-stack](../architecture/stack.md) : Go 1.27.3 « à figer au premier commit de code » ; Style Dictionary « à figer à l'introduction » ; genui 0.10.4 confirmé.
- [p-rm-backlog](../roadmap/backlog.md) (EP-01) : le premier commit de code Go crée `backend/go.mod` avec `go 1.27.3`.
- [p-rm-open-questions](../roadmap/open-questions.md) : Q-46 tranchée → pdr-0047 ; [p-rm-roadmap](../roadmap/roadmap.md) : Q-46 levée pour J2.

## Réexaminer si
- Une dépendance Go exige une toolchain plus récente que 1.27.3 ;
- une version de `genui` corrige un bogue bloquant pour la démo (montée ciblée, PR dédiée, [pdr-0010](pdr-0010-pinned-experimental-versions.md)).

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-29 | Acceptée ; Q-46 tranchée. Parole du porteur (conversation avec l'assistant, 2026-10-29), en réponse au tableau des questions présenté juste avant : « Pour les questions, utilise tes recommandations » | Benoît FONTAINE (porteur), conversation |

Pas d'archive brute.
