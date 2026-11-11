---
id: pdr-0091-rehearsals-close-q79-q80-q87
title: "PDR-0091 — Q-79, Q-80 et Q-87 closes sur constat du porteur en répétition"
area: decisions
status: validated
updated: 2026-11-11
sources: [product/sources/2026-10-31-repetition-micro.md, knowledge:rt-barge-in, knowledge:rt-gpt-live-delegation]
links: [p-rm-open-questions, p-rm-spikes, p-ar-voice-interruption, p-ar-voice-overlap, p-ar-voice-recovery, p-ar-frontend-screen, p-fn-nfr, p-sources, pdr-0076-014-silence-mic-correction-assistant-decided, pdr-0080-015-overlap-interrupt-delegation-link-assistant-decided, pdr-0082-016-voice-guard-and-repeat-request, pdr-0017-source-hierarchy-sheet-over-mockups, rt-barge-in, rt-gpt-live-delegation]
tags: [pdr, decision, questions-ouvertes, repetition, voix]
decision_status: acceptée
decided_on: 2026-11-11
decided_by: "Benoît FONTAINE (porteur), conversation Claude Code"
scope: technique
supersedes: []
superseded_by: null
---
# PDR-0091 — Q-79, Q-80 et Q-87 closes sur constat du porteur en répétition

> **En bref.** Le porteur tient Q-79 (coupure de piste sous Linux), Q-80 (horloges, NFR-02, réglages du chevauchement) et Q-87 (correction en vol) pour réglées par ses répétitions. La clôture repose **sur son constat seul** : aucun compte rendu de répétition n'est versé au dépôt, hormis celui du 2026-10-31.

Part de l'assistant : il a posé la question et consigné la réponse ; il n'a rien arbitré. Les mesures citées plus bas sont ses observations du journal, pas la parole du porteur.

## Contexte
- Q-79, Q-80 et Q-87 étaient ouvertes « avant J7, non bloquantes » ([p-rm-open-questions](../roadmap/open-questions.md)), à observer en répétition.
- Seule la répétition du 2026-10-31 est documentée ([répétition du 2026-10-31](../sources/2026-10-31-repetition-micro.md)). Elle laissait Q-79 non prouvée et Q-80 en partie mesurée.
- Le porteur a ensuite écrit (2026-11-11, conversation Claude Code), à propos d'une slide : « Dans le slide 2, il n'est indiqué qu'une répétition et une Q=80 encore ouverte. Ce qui est faux, j'ai fait d'autres répétitions, même encore une tout à l'heure. »

## Observations de l'assistant (journal du backend, pas des paroles du porteur)
Source : volume Docker `genesis-demo_journal`, fichiers `live_*.jsonl`.

| Observation | Valeur |
|---|---|
| Sessions avec un acte 1 mesurable | 31/10, 02/11, 03/11, 10/11 (deux), 11/11 (deux) |
| Squelette après le premier mot de l'accusé vocal | 0,07 à 0,10 s |
| Chiffres de l'agent Qualité après le squelette | 2,0 à 4,0 s |
| Écran de l'acte 1 complet après la délégation | 2,4 à 4,3 s |
| `voice.interrupted` de cause `overlap` | sessions du 10/11 (deux) et du 11/11 (trois événements sur deux sessions) |
| Appels de l'agent Qualité durant exactement 4,00 s (`COMPOSER_TIMEOUT`) | 10 sur 17 |

⚠️ Hypothèse non confirmée : les 10 appels à 4,00 s seraient des replis déterministes du composeur ; c'est une déduction de l'assistant, non vérifiée.

## Hypothèses
- ✅ Le porteur a répondu « Oui, toutes » à la question de l'assistant (voir Historique).
- ⚠️ Hypothèse non confirmée : aucun détail de mesure n'a été donné par le porteur ; ce qu'il a observé exactement n'est pas documenté.
- Non documenté à ce jour (écrit tel quel, sans conclusion de l'assistant) :
  - Q-79 : la preuve à l'oreille de la coupure de piste (`track.enabled = false`) sous `flutter_webrtc` Linux, pour la piste distante comme pour le micro local ;
  - Q-87 : une correction en vol prononcée pendant qu'une délégation est encore en cours ; le journal ne montre pas ce cas ;
  - Q-80 : le p90 de NFR-01 et les valeurs finales des `VOICE_OVERLAP_*` (la réponse du porteur ne précise pas si ces réglages sont figés).

## Options
Aucune alternative documentée dans la source : le porteur a répondu à une question fermée.

## Décision
Q-79, Q-80 et Q-87 passent à « Tranchée → pdr-0091 (2026-11-11) » dans le registre, **sur constat du porteur en répétition**. Aucune exigence, aucun réglage ni aucun code n'est modifié par cette PDR.

## Raisons
- Parole explicite du porteur : « Oui, toutes ».
- Les répétitions du porteur sont plus nombreuses que celles documentées (parole du 2026-11-11 ci-dessus), et le journal contient bien des sessions des 02/11, 03/11, 10/11 et 11/11.

## Options écartées
- Laisser ouvertes : écartée par le porteur.
- Verser un compte rendu de répétition : non demandé, non fourni. Aucune donnée n'a été inventée.

## Conséquences
- [p-rm-open-questions](../roadmap/open-questions.md) : Q-79, Q-80, Q-87 closes ; l'historique des cellules est conservé.
- [p-rm-spikes](../roadmap/spikes.md) (SP-11), [p-ar-voice-interruption](../architecture/voice-interruption.md), [p-ar-voice-overlap](../architecture/voice-overlap.md), [p-ar-voice-recovery](../architecture/voice-recovery.md), [p-fn-nfr](../functional/nfr.md) : leurs mentions « ⚠️ à observer en répétition » restent écrites telles quelles ; elles ne sont pas réécrites sans détail de mesure.
- Les données de ces questions ne sont pas versées au dépôt : à documenter si le porteur fournit un compte rendu.

## Réexaminer si
- Le porteur ou une répétition montre que la coupure de piste, la correction en vol ou la tenue de NFR-02 / NFR-01 ne tient pas.
- Un compte rendu de répétition contredit l'une des observations du journal ci-dessus.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-11-11 | Acceptée. Question de l'assistant : « Q-79, Q-80 et Q-87 sont-elles réglées par vos répétitions ? ». Réponse : « Oui, toutes » (conversation Claude Code). Juste avant, même jour et même canal : « Dans le slide 2, il n'est indiqué qu'une répétition et une Q=80 encore ouverte. Ce qui est faux, j'ai fait d'autres répétitions, même encore une tout à l'heure. » | Benoît FONTAINE (porteur) |

Pas d'archive brute.
