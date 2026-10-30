---
id: pdr-0060-small-openai-text-model-guided-a2ui
title: "PDR-0060 — Petit modèle texte OpenAI guidé par les écrans d'exemple, avec repli déterministe"
area: decisions
status: validated
updated: 2026-10-30
sources: [specs/006-j3-act1-backend/status.md]
links: [p-rm-open-questions, p-ar-backend, p-ar-agents-protocols, p-ar-quality, p-ar-stack, p-rm-spikes, p-fn-nfr, pdr-0023-example-guided-composition, pdr-0036-real-a2a-agents-produce-a2ui, pdr-0030-llm-budget-20-eur, pdr-0012-voice-provider-openai]
tags: [pdr, decision, llm, a2ui, latence]
decision_status: acceptée
decided_on: 2026-10-30
decided_by: "Benoît FONTAINE (porteur), conversation avec l'assistant du 2026-10-30 (questionnaire)"
scope: mixte
supersedes: []
superseded_by: null
---
# PDR-0060 — Petit modèle texte OpenAI guidé par les écrans d'exemple, avec repli déterministe

> **En bref.** Tranche Q-17. Un petit modèle texte OpenAI (même clé, même budget) génère l'A2UI, guidé par les écrans d'exemple ; choisi par une mesure courte en J3 ; repli sur la composition déterministe si la mesure échoue, et on le dit au public.

Part de l'assistant : recommandation validée par le porteur ; mise en forme et propagation par l'assistant.

## Contexte
Q-17 : NFR-02/03 imposent une latence courte. 006 : les trois agents composent de façon déterministe (fixtures de `contracts/a2ui/genesis/v1/`), en conflit avec [pdr-0023](pdr-0023-example-guided-composition.md) (« aucune séquence pré-écrite rejouée comme générée »).

## Hypothèses
- ⚠️ Hypothèse non confirmée : un petit modèle texte tient NFR-02 et NFR-03 ; c'est l'objet de la mesure de J3.

## Options
1. **Option retenue** (voir Décision).
2. Alternatives : voir « Options écartées ».

## Décision
**Décision** : un petit modèle texte OpenAI (même clé, même budget, [pdr-0030](pdr-0030-llm-budget-20-eur.md)) génère l'A2UI derrière le port `Composer`, guidé par les écrans d'exemple (`contracts/a2ui/genesis/v1/`). Le modèle est choisi par une mesure courte de latence et de qualité en J3 (critère : NFR-02 squelette < 1,5 s ; NFR-03 acte 1 < 8 s). Si la mesure échoue, repli sur la composition déterministe actuelle, **assumé devant le public**. La phrase du porteur : « Un petit modèle texte OpenAI guidé par les écrans d'exemple, choisi par une mesure courte en J3 ; si la latence dépasse NFR-02/03, retour aux écrans fixes, assumé devant le public. »

## Raisons
- Respecte pdr-0023 (c'en est la mise en œuvre) ; un seul fournisseur, un seul budget.
- Parole du porteur : Question « Q-17 : comment les agents génèrent-ils l'A2UI ? (aujourd'hui : écrans fixes, ce qui contredit pdr-0023) » → option « Petit LLM OpenAI + repli (Recommandé) » : « Un petit modèle texte OpenAI guidé par les écrans d'exemple, choisi par une mesure courte en J3 ; si la latence dépasse NFR-02/03, retour aux écrans fixes, assumé devant le public. ».

## Options écartées
- Écrans fixes seuls : contredit pdr-0023 ; un autre fournisseur : ajoute une clé et un budget.

## Conséquences
- [p-ar-backend](../architecture/backend.md), [p-ar-agents-protocols](../architecture/agents-protocols.md), [p-ar-quality](../architecture/quality.md) : mesure NFR-02/03 en J3 ; le nom du modèle reste à fixer par la mesure (non décidé).
- Débloque J3.

## Réexaminer si
- la mesure J3 dépasse NFR-02/03 (repli) ; le budget de 20 € est menacé.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-30 | Acceptée. Parole du porteur : Question « Q-17 : comment les agents génèrent-ils l'A2UI ? (aujourd'hui : écrans fixes, ce qui contredit pdr-0023) » → option « Petit LLM OpenAI + repli (Recommandé) » : « Un petit modèle texte OpenAI guidé par les écrans d'exemple, choisi par une mesure courte en J3 ; si la latence dépasse NFR-02/03, retour aux écrans fixes, assumé devant le public. ». Tranche Q-17. | Benoît FONTAINE (porteur) |
| 2026-10-30 | pdr-0023 reste valable (c'en est la mise en œuvre) ; ligne d'historique ajoutée à pdr-0023. | Assistant |
| 2026-10-30 | Mise en œuvre planifiée en 012 (pdr-0070), parole du porteur citée dans cette PDR | Benoît FONTAINE (porteur), conversation |

Pas d'archive brute.
