---
id: pdr-0067-gpt-live-session-cap-30-min
title: "PDR-0067 — Plafond de session GPT-Live : 30 minutes par défaut"
area: decisions
status: validated
updated: 2026-10-30
sources: [product/roadmap/open-questions.md]
links: [p-rm-open-questions, pdr-0030-llm-budget-20-eur, pdr-0052-one-gpt-live-session-per-act-recommended, rt-gpt-live-lifecycle]
tags: [pdr, decision, gpt-live, budget]
decision_status: acceptée
decided_on: 2026-10-30
decided_by: "Benoît FONTAINE (porteur), conversation avec l'assistant du 2026-10-30"
scope: technique
supersedes: []
superseded_by: null
---
# PDR-0067 — Plafond de session GPT-Live : 30 minutes par défaut

> **En bref.** Le plafond par défaut d'une session GPT-Live (`VOICE_MAX_SESSION`) est fixé à **30 minutes** : il couvre largement un acte et borne le coût d'une session à environ 1,50 $.

Part de l'assistant : recommandation et mise en forme.

## Contexte
Mécanisme livré par 003 : au plafond, fermeture propre de la session. GPT-Live est facturé environ 0,05 $/min et limite une session à 2 h ([rt-gpt-live-lifecycle], [rt-gpt-live-overview]) ; budget LLM total : 20 € ([pdr-0030](pdr-0030-llm-budget-20-eur.md)) ; une session par acte recommandée ([pdr-0052](pdr-0052-one-gpt-live-session-per-act-recommended.md)). Question Q-68 ([p-rm-open-questions](../roadmap/open-questions.md)).

## Options
1. **30 min** (retenue)
2. 20 min
3. 45 min
4. Pas de plafond hors les 2 h du fournisseur

## Décision
- `VOICE_MAX_SESSION=30m` est la valeur par défaut retenue (celle du `docker-compose.yaml`), surchargeable par `.env` en répétition.

## Raisons
Recommandation de l'assistant validée par le porteur. Question posée : « Q-68 et Q-76 : je les tranche selon mes recommandations (session GPT-Live plafonnée à 30 min ; limite « décision perdue si on redemande une vue après l'acte 3 » acceptée) ? » Réponse : « Oui, les deux (Recommandé) ».

## Options écartées
- 20 min : marge trop faible pour un acte commenté avec questions.
- 45 min et plus : coût par session moins borné, proche de la saturation du contexte.

## Conséquences
- [p-ar-stage-runtime](../architecture/stage-runtime.md) et le compose : valeur par défaut confirmée, plus « provisoire ».

## Réexaminer si
- Les répétitions montrent un acte qui dépasse 20 min, ou une coupure de session gênante.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-30 | Acceptée ; Q-68 tranchée (réponse : « Oui, les deux (Recommandé) ») | Benoît FONTAINE (porteur), conversation |

Pas d'archive brute.
