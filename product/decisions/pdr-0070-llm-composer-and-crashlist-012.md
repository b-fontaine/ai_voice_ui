---
id: pdr-0070-llm-composer-and-crashlist-012
title: "PDR-0070 — Compositeur LLM (pdr-0060) puis CrashList réel : fonctionnalité 012"
area: decisions
status: validated
updated: 2026-10-30
sources: [product/decisions/_archive/2026-10-30-essai-micro-diagnostic.md]
links: [p-rm-open-questions, p-rm-roadmap, pdr-0062-standing-rule-sheet-wins-assistant-decides-ui-details, pdr-0060-small-openai-text-model-guided-a2ui, pdr-0023-example-guided-composition, pdr-0014-six-component-catalog, pdr-0007-closed-catalog-stage-theme, p-fn-requirements]
tags: [pdr, decision, composition, catalogue, crashlist]
decision_status: acceptée
decided_on: 2026-10-30
decided_by: "Benoît FONTAINE (porteur), conversation avec l'assistant du 2026-10-30 (questionnaire après l'essai au micro)"
scope: mixte
supersedes: []
superseded_by: null
---
# PDR-0070 — Compositeur LLM (pdr-0060) puis CrashList réel : fonctionnalité 012

> **En bref.** Construire d'abord réellement la composition par petit modèle texte (pdr-0060, jamais construite), avec mesure de latence et repli déterministe, puis le composant CrashList réel (données, schéma, liste blanche, widget, choix par l'IA). Fonctionnalité 012.

Part de l'assistant : recommandation, mise en forme et consignation de la parole du porteur.

## Contexte
L'essai montre que CrashList n'apparaît jamais même demandé explicitement ; pdr-0060 (composition guidée par exemples) n'a jamais été implémentée : la composition est restée déterministe.

Observations du porteur (conversation du 2026-10-30) : « Je n'ai pas vu la comparaison dans l'essai que tu m'as demandé ; Le composant Crashlist n'est jamais apparu, même après l'avoir demandé explicitement ; Lui dire stop ou essayer de lui couper la parole ne fonctionne pas ; Quand je dis stop, rien ne se passe ; Quand je m'interrompts, elle compte ça comme une fin de phrase ; par contre, elle ne repère que ma voix, les bruits autour n'ont pas d'impact ; C'est toujours écrit Acte 1/3 en haut à droite, même après avoir bloqué la release ; Cliquer sur "Bloquer la release" n'a eu un effet qu'après le discours de l'IA ».

Diagnostic complet (contre-vérifié sur les journaux des sessions) : [diagnostic de l'essai au micro](_archive/2026-10-30-essai-micro-diagnostic.md).

## Options
1. **Construire le LLM puis CrashList** (retenue).
2. Reporter l'un des deux.

## Décision
Question posée : « Composition par l'IA (pdr-0060, jamais construite) et CrashList : que fait-on ? » Réponse : « Construire le LLM puis CrashList (Recommandé) ».
- **012-a** : mise en œuvre réelle de pdr-0060 (petit modèle texte OpenAI guidé par les écrans d'exemple, mesure de latence NFR-02/NFR-03, repli sur la composition déterministe si trop lent).
- **012-b** : CrashList réel : données du jeu, schéma du catalogue, liste blanche, widget avec états squelette/neutre, choix par l'IA selon la demande.

## Raisons
Le choix d'un composant selon la demande suppose la composition par l'IA ; CrashList en dépend.

## Options écartées
- Reporter : CrashList resterait introuvable.

## Conséquences
- Fonctionnalité **012** ; catalogue ([p-fn-catalog](../functional/catalog.md)) et jeu de données concernés.
- Les coûts restent sous pdr-0030 (20 €).

## Réexaminer si
- La mesure de latence du petit modèle dépasse durablement les budgets : repli déterministe conservé.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-30 | Acceptée. pdr-0060 complétée (mise en œuvre planifiée en 012). Réponse : « Construire le LLM puis CrashList (Recommandé) ». | Benoît FONTAINE (porteur), conversation |

Archive brute : [diagnostic de l'essai au micro](_archive/2026-10-30-essai-micro-diagnostic.md).
