---
id: pdr-0032-obs-video-fallback-a2ui-replay-act
title: "PDR-0032 — Secours = vidéo OBS gérée par le porteur ; l'app enregistre et rejoue le seul flux A2UI, et le rejeu devient l'acte 4"
area: decisions
status: validated
updated: 2026-10-29
sources: [conversation porteur 2026-10-29, product/sources/product-description.pdf#p2, product/sources/product-description.pdf#p3, product/sources/product-description.pdf#p4, product/sources/product-description.pdf#p11, knowledge:genui-a2ui-messages]
links: [pdr-0006-replay-fallback-must, pdr-0004-mvp-three-acts, pdr-0027-talk-context-meetup-flutter-nantes, pdr-0033-optional-shortcuts-mouse-first, pdr-0018-a2ui-v09-genui-0-10-4, p-ar-replay, p-ar-overview, p-ar-stage-runtime, p-ar-quality, p-fn-requirements, p-fn-nfr, p-fn-business-rules, p-fn-risks-acceptance, p-fn-screen, p-fn-feature-voice-screen-generation, p-rm-backlog, p-rm-roadmap, p-rm-spikes, p-rm-open-questions, genui-a2ui-messages]
tags: [pdr, decision, replay, fallback, video, acte-4]
decision_status: acceptée
decided_on: 2026-10-29
decided_by: "Benoît FONTAINE (porteur), conversation avec l'assistant du 2026-10-29"
scope: mixte
supersedes: [pdr-0006-replay-fallback-must]
superseded_by: null
---
# PDR-0032 — Secours vidéo, rejeu A2UI en acte 4

> **En bref.** Le mode secours n'est plus dans l'app : c'est une **vidéo enregistrée avec OBS Studio**, gérée par le porteur, qui choisira sur place entre direct et vidéo. L'app garde l'enregistrement et le rejeu (FR-09, Must), **limités au flux A2UI** (ni voix ni transcription). Le rejeu devient un **acte de la démo** : l'acte 4 est inclus. FR-10, NFR-07 et le scénario « Bascule en mode secours » sont retirés. Remplace [pdr-0006](pdr-0006-replay-fallback-must.md). Tranche Q-18, Q-19 et Q-36 ; Q-50 et Q-51 deviennent sans objet. Q-52 reste **ouverte** (proposition de l'assistant, à confirmer).

Part de l'assistant : consignation et propagation ; proposition sur Q-52 (voir ci-dessous), non décidée.

## Contexte
- [pdr-0006](pdr-0006-replay-fallback-must.md) (fiche § 3, § 4, § 8) : rejeu 0,25×–2× Must, et mode secours intégré en < 2 s par raccourci (FR-10, NFR-07).
- Questions ouvertes : contenu de l'enregistrement (Q-18), acte 4 (Q-19), session de référence et persistance (Q-36, Q-50), bascule et retour au direct (Q-51), pas de ←/→ (Q-52).

## Hypothèses
- ✅ Le porteur produit et lance lui-même la vidéo de secours (logistique, hors périmètre de l'assistant, [pdr-0027](pdr-0027-talk-context-meetup-flutter-nantes.md)).
- ✅ Rejouer le flux A2UI ne demande ni réseau ni LLM : les messages v0.9 sont réinjectés dans l'ordre [genui-a2ui-messages].

## Options
1. **Secours vidéo hors app ; rejeu A2UI seul, en acte 4** (retenue)
2. Mode secours intégré par raccourci (pdr-0006)

## Décision
| Élément | Décision |
|---|---|
| Secours | vidéo OBS Studio, gérée par le porteur ; décision live / vidéo prise par le porteur sur place, après un test en conditions réelles |
| Mode secours intégré | **supprimé** : FR-10, NFR-07, RG-20 et le scénario S-04 « Bascule en mode secours » sont retirés |
| Enregistrement | flux A2UI seul, horodaté (messages v0.9) ; ni audio ni transcription |
| Rejeu (FR-09, Must) | 0,25×–2×, sans réseau ni LLM ; c'est l'**acte 4** du déroulé (fiche § 2 : « l'acte 1 repasse au ralenti, synchronisé avec le JSON ») |
| Session rejouée | la session en cours (pas de session de référence, pas de persistance au-delà de la session) |

Proposition de l'assistant, **non décidée** (Q-52 ouverte, à confirmer par le porteur) : pas de pas-à-pas ←/→ imposé ; lecture, pause et vitesse suffisent. Le « Rien de tout ça » du porteur vise Q-51 et Q-52 ensemble et sa justification porte sur le choix direct / vidéo, pas sur le pas-à-pas.

## Raisons
- Parole du porteur (2026-10-29), Q-36 : « Non, le mode de secours sera une vidéo enregistrée avec OBS Studio ».
- Parole du porteur (2026-10-29), Q-51 (et Q-52, voir la proposition ci-dessus) : « Rien de tout ça. Je ferai un test en conditions réelles avant le talk et je jugerai moi même si je lance un backup vidéo ou si je fais du live ».
- Parole du porteur (2026-10-29), Q-18 : « Flux A2UI seul » ; Q-19 : « inclus le rejeu d'un Flux A2UI, ce sera utile pour la démo ».

## Options écartées
- **Mode secours intégré** : remplacé par la vidéo, plus simple et indépendante de l'app.
- **Rejeu de la voix ou de la transcription** : écarté par le porteur (Q-18).
- **Session de référence committée** : sans objet sans mode secours ; la fiche exclut la persistance (§ 3).

## Conséquences
- [p-fn-requirements](../functional/requirements.md), [p-fn-nfr](../functional/nfr.md) : FR-10 et NFR-07 « retirés par pdr-0032 » ; FR-09 reste Must.
- [p-fn-feature-voice-screen-generation](../functional/features/voice-screen-generation.feature) : S-04 commenté, avec la référence.
- [p-fn-business-rules](../functional/business-rules.md) : RG-19 précisée, RG-20 retirée.
- [p-fn-risks-acceptance](../functional/risks-acceptance.md) : D4 retiré ; plan B niveau 4 = vidéo (porteur).
- [p-ar-replay](../architecture/replay.md) réécrit ; [p-rm-backlog](../roadmap/backlog.md) EP-07 ; [p-rm-roadmap](../roadmap/roadmap.md) J6 ; [p-rm-spikes](../roadmap/spikes.md) SP-05.
- [pdr-0004](pdr-0004-mvp-three-acts.md) : l'acte 4 n'est plus optionnel (historique).

## Réexaminer si
- Le porteur veut à nouveau un secours intégré à l'app, ou rejouer la voix.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-29 | Acceptée : « le mode de secours sera une vidéo enregistrée avec OBS Studio » ; « Flux A2UI seul » ; « inclus le rejeu d'un Flux A2UI, ce sera utile pour la démo » (conversation) | Benoît FONTAINE (porteur) |
| 2026-10-29 | Q-52 lue comme « pas de pas-à-pas imposé » ; à confirmer par le porteur | Assistant |
| 2026-10-29 | Revue : Q-52 retirée des questions tranchées (reste ouverte, proposition jointe) ; enregistrement ramené à « flux A2UI seul (messages v0.9) », conformément à Q-18 | Assistant |

Pas d'archive brute.
