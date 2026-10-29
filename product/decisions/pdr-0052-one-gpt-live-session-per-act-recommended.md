---
id: pdr-0052-one-gpt-live-session-per-act-recommended
title: "PDR-0052 — Une session GPT-Live par acte"
area: decisions
status: validated
updated: 2026-10-29
sources: [specs/002-sp-02-gpt-live-sdp-relay/notes-s1.md, knowledge:rt-gpt-live-lifecycle, knowledge:rt-gpt-live-webrtc-session]
links: [p-rm-open-questions, p-rm-spikes, p-ar-stage-runtime, p-ar-backend, pdr-0004-mvp-three-acts, pdr-0027-talk-context-meetup-flutter-nantes, pdr-0030-llm-budget-20-eur, rt-gpt-live-lifecycle, rt-gpt-live-webrtc-session, rt-gpt-live-overview]
tags: [pdr, decision, voix, gpt-live, session, acte]
decision_status: acceptée
decided_on: 2026-10-29
decided_by: "Benoît FONTAINE (porteur), conversation du 2026-10-29"
scope: technique
supersedes: []
superseded_by: null
---
# PDR-0052 — Une session GPT-Live par acte

> **En bref.** Tranche Q-53. Une session par acte : la limite de 2 h ne gêne pas, mais le contexte pourrait atteindre ~94 % à 45 min dans le cas pessimiste mesuré. ⚠️ À confirmer sur un scénario réaliste.

Part de l'assistant : recommandation acceptée par le porteur.

## Contexte
- Q-53 : une session par acte ou une seule pour toute la démo ? ([p-ar-stage-runtime](../architecture/stage-runtime.md)). Le talk dure 45 min ([pdr-0027](pdr-0027-talk-context-meetup-flutter-nantes.md)).
- Mesuré en SP-02 (2026-10-29) : création d'une session ~1 s ; `expires_at` = +2 h par session ; facturation 0,05 $/min, 15 s minimum ; `session.usage.updated` donne `usage.seconds` et `context_window.usage_ratio` ([rt-gpt-live-lifecycle], [rt-gpt-live-webrtc-session]).
- Progression du contexte ~0,00035/s dans un essai où l'IA parle en continu : extrapolation **pessimiste** ~94 % à 45 min ; le moteur remplace le contexte à 90 %.
- Coût cumulé du spike : 0,26 € ([pdr-0030](pdr-0030-llm-budget-20-eur.md)).

## Hypothèses
- ✅ La limite de durée (2 h) dépasse largement le talk.
- ⚠️ Hypothèse non confirmée : l'extrapolation pessimiste (parole continue) surestime l'usage réel d'un scénario de démo ; à mesurer sur un scénario complet (Q-53 tranchée ; voir « Réexaminer si »).
- ⚠️ Hypothèse non confirmée : changer de session entre deux actes est imperceptible pour le public (~1 s de création, perte du contexte oral) ; à tester en répétition (Q-53 tranchée).

## Options
1. **Une session par acte** (retenue).
2. Une session unique pour toute la démo.

## Décision
**Décision** : ouvrir une nouvelle session à chaque acte ([pdr-0004](pdr-0004-mvp-three-acts.md)), l'état utile étant repris des instructions et de l'état de l'orchestrateur.

## Raisons
- Garde le contexte loin du seuil de remplacement de 90 % en cas pessimiste.
- Création d'une session rapide (~1 s) ; coût négligeable (15 s minimum facturées).

## Options écartées
- Session unique : possible si le contexte reste sous 90 % sur un scénario réaliste ; non écartée définitivement.

## Conséquences
- [p-ar-stage-runtime](../architecture/stage-runtime.md) : transitions d'acte = ouverture d'une session ; à tester en répétition.
- [p-ar-backend](../architecture/backend.md) : `voice-session` doit pouvoir rouvrir une session sans intervention du speaker.
- Décision acquise le 2026-10-29, avant l'échéance de J3 (2/11).

## Réexaminer si
- un scénario complet mesure un contexte < 90 % sur 45 min (la session unique redevient viable) ;
- la reprise de contexte entre actes se remarque à l'oreille.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-29 | Proposée, après SP-02 (aucune parole du porteur) | Assistant |
| 2026-10-29 | Acceptée. Le porteur a répondu « Tes recommandations me conviennent. » (conversation du 2026-10-29), après que l'assistant lui a présenté un tableau récapitulant ses trois recommandations (Q-47 → pdr-0050, Q-43 → pdr-0051, Q-53 → pdr-0052). Tranche Q-53. | Benoît FONTAINE (porteur) |

Pas d'archive brute.
