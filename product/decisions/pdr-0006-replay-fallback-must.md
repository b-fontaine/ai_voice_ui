---
id: pdr-0006-replay-fallback-must
title: "PDR-0006 — Enregistrement et rejeu de session : exigence Must et mode secours"
area: decisions
status: superseded
updated: 2026-10-29
sources: [product/sources/product-description.pdf#p3, product/sources/product-description.pdf#p4, product/sources/product-description.pdf#p7, product/sources/product-description.pdf#p9, product/sources/product-description.pdf#p11, knowledge:ds-widgetbook-4-genui, knowledge:adr-0002-orchestrator-backend]
links: [pdr-0032-obs-video-fallback-a2ui-replay-act, p-fn-requirements, p-fn-nfr, p-fn-screen, p-fn-risks-acceptance, p-ar-replay, p-ar-frontend, p-ar-stage-runtime, p-rm-backlog, p-rm-open-questions, pdr-0001-conference-demo-deliverable, pdr-0004-mvp-three-acts, pdr-0005-frozen-fictional-dataset, adr-0002-orchestrator-backend, ds-widgetbook-4-genui]
tags: [pdr, decision, replay, fallback, resilience]
decision_status: remplacée par pdr-0032-obs-video-fallback-a2ui-replay-act
decided_on: 2026-10-28
decided_by: "Benoît FONTAINE (porteur), via la fiche produit du 2026-10-28"
scope: mixte
supersedes: []
superseded_by: pdr-0032-obs-video-fallback-a2ui-replay-act
---
# PDR-0006 — Rejeu = exigence Must et mode secours

> **Remplacée par [pdr-0032](pdr-0032-obs-video-fallback-a2ui-replay-act.md)** (2026-10-29) : le secours est une vidéo OBS gérée par le porteur ; FR-10 et NFR-07 sont retirés ; le rejeu (flux A2UI seul) reste Must et devient l'acte 4. Le texte ci-dessous est conservé pour l'historique.

> **En bref.** Chaque génération est enregistrée et peut être rejouée de 0,25× à 2×. Le même mécanisme sert de mode secours, déclenché par un raccourci, en moins de 2 s et sans redémarrer l'app. Ce n'est pas un bonus : c'est la parade au risque réseau.

Part de l'assistant : mise en forme de la fiche. Aucune recommandation.

## Contexte
- Fiche § 8 (p. 11) : « Le risque principal […] est scénique : une démo vocale en direct sur le Wi-Fi d'une conférence. Le mode rejeu est donc une exigence Must, pas un bonus. »
- Risque « Réseau de la salle instable » : probabilité haute, impact bloquant ; parade « mode secours en un raccourci » (fiche § 8).

## Hypothèses
- ✅ La bascule doit fonctionner Wi-Fi coupé (fiche § 8, critères d'acceptation).
- ⚠️ Hypothèse non confirmée : le rejeu restitue aussi l'audio (voix du speaker et de l'IA). La fiche parle de « génération » et de JSON, pas d'audio → [p-rm-open-questions](../roadmap/open-questions.md) (Q-18).
- ⚠️ Hypothèse non confirmée : quelle session est rejouée en secours (une session de répétition choisie à l'avance, ou la dernière) → [p-rm-open-questions](../roadmap/open-questions.md) (Q-50, liée à Q-36).

## Options
Aucune alternative documentée dans la source, hormis le statut « bonus » que la fiche rejette.

## Décision
| Exigence | Contenu | Priorité |
|---|---|---|
| FR-09 | Toute la génération est enregistrée et rejouable de 0,25× à 2× | Must |
| FR-10 | Un raccourci clavier bascule en mode secours (rejeu d'une session enregistrée) | Must |
| NFR-07 | Bascule en moins de 2 s, sans redémarrer l'app ; mesuré Wi-Fi coupé | — |

Le mode secours est signalé par un indicateur discret (état « Secours » de l'orbe, fiche § 6). Raccourcis proposés : B (bascule), ←/→ (rejeu), à valider (fiche § 6).

## Raisons
- Fiche § 8 : seule parade au risque réseau, jugé bloquant.
- La même zone « Rejeu » sert la pédagogie (acte 4 optionnel, rejeu synchronisé avec le JSON) et la résilience (fiche § 6).

## Options écartées
- **Rejeu en bonus** : écarté par la fiche § 8 (« pas un bonus »).

## Conséquences
- **Architecture** : le mode secours doit fonctionner **sans réseau**, donc le journal rejouable doit être disponible côté app, alors que l'orchestrateur est côté backend [adr-0002-orchestrator-backend]. Format, emplacement et horodatage du journal → [p-ar-replay](../architecture/replay.md).
- **Mesure** : NFR-02 et NFR-03 se mesurent par l'« horodatage du journal A2UI » (fiche § 5) : le journal sert aussi d'instrument de mesure → [p-ar-quality](../architecture/quality.md).
- **Knowledge** : Widgetbook 4 sait rejouer des surfaces A2UI en cache (`CachedSurface`) [ds-widgetbook-4-genui] ; piste à évaluer pour les stories, pas une décision.
- **Fonctionnel** : FR-11 (remise à vide) et FR-10 (secours) sont à tester en répétition (fiche § 8) → [p-fn-risks-acceptance](../functional/risks-acceptance.md).
- **Roadmap** : à livrer avant les répétitions sur réseau mobile → [p-rm-backlog](../roadmap/backlog.md), [p-ar-stage-runtime](../architecture/stage-runtime.md).

## Réexaminer si
- Le porteur décide de rejouer aussi l'audio, ou de rejouer une session préenregistrée plutôt que la session en cours.
- Les répétitions montrent qu'une bascule en moins de 2 s est irréaliste avec le journal retenu.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-28 | Acceptée dans la fiche produit (§ 3, § 4, § 5, § 8) | Benoît FONTAINE (porteur) |
| 2026-10-28 | Consignée en PDR | Assistant (mise en forme) |
| 2026-10-29 | Remplacée par pdr-0032 : « le mode de secours sera une vidéo enregistrée avec OBS Studio » ; « Flux A2UI seul » (conversation) | Benoît FONTAINE (porteur) |

Pas d'archive brute.
