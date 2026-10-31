---
id: pdr-0078-012-composer-choices-confirmed
title: "PDR-0078 — 012 : lexique, squelette anticipé et contrôle du compose confirmés"
area: decisions
status: validated
updated: 2026-10-31
sources: [knowledge:rt-barge-in]
links: [pdr-0074-012-llm-composer-gateway-crashlist-details, pdr-0075-013-design-ergonomics-details-assistant-decided, pdr-0060-small-openai-text-model-guided-a2ui, pdr-0038-latency-measured-on-app-clock, p-ar-llm-composer, p-ar-security, p-rm-open-questions]
tags: [pdr, decision, compositeur, latence, ci, 012]
decision_status: acceptée
decided_on: 2026-10-31
decided_by: "Benoît FONTAINE (porteur), conversation, 2026-10-31"
scope: technique
supersedes: []
superseded_by: null
---
# PDR-0078 — 012 : lexique, squelette anticipé et contrôle du compose confirmés

> **En bref.** Le porteur a tranché Q-81, Q-82 et Q-84 selon les recommandations de l'assistant ; Q-83 était déjà tranchée par pdr-0075.

## Contexte
Questions ouvertes par 012 ([pdr-0074](pdr-0074-012-llm-composer-gateway-crashlist-details.md)) : vues refusées (Q-81), squelette anticipé (Q-82), contrôle du compose sur la porte (Q-84).

## Hypothèses
- ⚠️ Hypothèse non confirmée : NFR-02 tient avec le squelette anticipé sur l'horloge de l'app → [Q-82](../roadmap/open-questions.md), à remesurer en répétition.

## Options
1. **Retenues** : Q-81 lexique actuel ; Q-82 squelette anticipé ; Q-84 branchement sur `verify.sh --full`.
2. Écartées : étendre le lexique, écrans fixes d'emblée, laisser le contrôle hors porte.

## Décision
Question posée le 2026-10-31 : « Je tranche Q-81, Q-82, Q-83 et Q-84 selon les recommandations (et je fais moi-même la modification de Q-84 dans tools/loop/verify.sh) ? Q-78, Q-79 et Q-80 restent pour ton prochain essai au micro. » ; réponse du porteur : « Oui, les quatre (Recommandé) ».
- **Q-81** (option 1) : lexique actuel conservé, `ParseIntent` seul juge ; ajusté en répétition.
- **Q-82** (option 1) : squelette anticipé conservé ; NFR-02 remesuré sur l'horloge de l'app ([pdr-0038](pdr-0038-latency-measured-on-app-clock.md)) en répétition ; **retour aux écrans fixes ([pdr-0060](pdr-0060-small-openai-text-model-guided-a2ui.md)) si p90 > 8 s ou budget menacé**.
- **Q-83** : déjà tranchée par [pdr-0075](pdr-0075-013-design-ergonomics-details-assistant-decided.md) D2 ; rien à changer, vérification seulement.
- **Q-84** (option 1) : **faite** par le porteur sur `main` (commit `bc50b45`) : `verify.sh --full` lance `backend/check-compose.sh` et `backend/check-compose-selftest.sh` ; arrive dans le worktree à la prochaine publication.

## Raisons
Réponse du porteur citée ci-dessus.

## Options écartées
Voir Options (aucune alternative n'a été retenue par le porteur).

## Conséquences
- Q-81, Q-82, Q-84 tranchées ; Q-83 inchangée. Q-78, Q-79, Q-80 restent des observations au micro.
- [p-ar-llm-composer](../architecture/llm-composer.md) et [p-ar-security](../architecture/security.md) : statut inchangé, aucun écart.

## Réexaminer si
- p90 de NFR-02 > 8 s sur l'horloge de l'app, ou budget NFR-11 menacé ; vue légitime refusée à tort en répétition.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-31 | Acceptée sur la parole du porteur citée ci-dessus (conversation) ; Q-84 réalisée par le porteur (`bc50b45`) | Benoît FONTAINE (porteur) |

Pas d'archive brute.
