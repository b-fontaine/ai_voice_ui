---
id: pdr-0077-011b-overlap-interrupt-delegation-link
title: "PDR-0077 — Fonctionnalité 011b : interruption sur chevauchement de parole et liaison animée de délégation"
area: decisions
status: validated
updated: 2026-10-31
sources: [product/sources/product-description.pdf#p5, knowledge:rt-barge-in]
links: [pdr-0069-voice-interruption-hybrid-stop-011, pdr-0073-011-voice-interaction-details-assistant-decided, pdr-0072-design-ergonomics-013, pdr-0075-013-design-ergonomics-details-assistant-decided, p-ar-voice-interruption, p-fn-screen, p-rm-open-questions, p-rm-roadmap]
tags: [pdr, decision, voix, interruption, rail, 011b]
decision_status: acceptée
decided_on: 2026-10-31
decided_by: "Benoît FONTAINE (porteur), conversation, 2026-10-30 (Q-77) et 2026-10-31 (Q-85)"
scope: mixte
supersedes: []
superseded_by: null
---
# PDR-0077 — Fonctionnalité 011b : interruption sur chevauchement de parole et liaison animée de délégation

> **En bref.** Le porteur a tranché Q-77 (option B) et Q-85 (« Oui, maintenant ») : tout mot significatif du speaker pendant que l'IA parle l'interrompt, et une liaison animée relie l'orchestrateur aux agents sollicités dans le rail. Les deux sont livrés par la fonctionnalité **011b**, **à faire en premier**, avant le reste de J7.

L'assistant a recommandé les deux options ; le porteur a décidé. Les détails de réalisation seront consignés par la boucle (pdr-0062) à l'étape « Définir » de 011b.

## Contexte
- [pdr-0069](pdr-0069-voice-interruption-hybrid-stop-011.md) ne publie `voice.interrupted` que sur le mot d'arrêt ; 011 est livrée ainsi (S-05 en partie, Q-77).
- La fiche prévoit une liaison animée de délégation dans le rail ([p-fn-screen](../functional/screen.md)) ; jamais livrée (Q-85, revue du plan de 013).

## Hypothèses
- ⚠️ Hypothèse non confirmée : latence attendue ≈ 1 s, à mesurer en répétition (Q-80).

## Options
1. **Q-77 B : déclencheur dès 011 (retenu).**
2. Garder le mot d'arrêt seul (état de 011).
3. Q-85 : faire la liaison maintenant (retenu) ou la reporter.

## Décision
**Q-77.** Question posée le 2026-10-30 : « Q-77 : couper la parole à l'IA simplement en parlant (sans « Stop ») ? » ; réponse du porteur : « B. Déclencheur dès 011 (Recommandé) ». Contenu :
- tout mot significatif prononcé par le speaker pendant que l'IA parle déclenche l'interruption : son coupé côté app, orbe « Interrompue » puis « Écoute », délégations en vol annulées, mêmes effets que le mot d'arrêt de pdr-0069, **sans retrait des surfaces complètes** ;
- protection contre l'écho : ignorer les mots d'entrée présents dans la transcription de sortie récente de l'IA ;
- mots vides exclus, longueur minimale configurable ;
- interrupteur `VOICE_OVERLAP_INTERRUPT`, **activé par défaut** ;
- latence attendue ≈ 1 s.

**Q-85.** Question posée le 2026-10-31 : « Q-85 : la fiche prévoit une liaison animée entre l'orchestrateur et les agents sollicités dans le rail (montrer la délégation). Jamais livrée. On la fait ? » ; réponse du porteur : « Oui, maintenant (Recommandé) ». Contenu : connecteur animé orchestrateur → chaque agent sollicité, livré avec 011b.

**Ordonnancement.** 011 étant livrée, c'est la fonctionnalité **011b**, **prochaine à faire, en premier**, avant le reste de J7.

## Raisons
- Réponses du porteur citées ci-dessus (2026-10-30, 2026-10-31).
- Couper la parole sans dire « Stop » est le comportement naturel attendu en démo vocale ([rt-barge-in]).

## Options écartées
- Mot d'arrêt seul : écarté par le porteur (option B choisie).
- Report de la liaison animée : écarté (« Oui, maintenant »).

## Conséquences
- Spec `specs/011b-…` ; mise à jour de [p-ar-voice-interruption](../architecture/voice-interruption.md) et [p-fn-screen](../functional/screen.md) à la livraison.
- Complète pdr-0069 et pdr-0073 ; Q-77 et Q-85 tranchées ; S-05 complété à la livraison.
- Nouvelle variable de configuration `VOICE_OVERLAP_INTERRUPT`.

## Réexaminer si
- Fausses interruptions (écho, bruit) en répétition sur enceinte ; latence nettement > 1 s (Q-80).

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-31 | Acceptée sur la parole du porteur citée ci-dessus (Q-77 le 2026-10-30, Q-85 le 2026-10-31, conversation) | Benoît FONTAINE (porteur) |

Pas d'archive brute.
