---
id: pdr-0001-conference-demo-deliverable
title: "PDR-0001 — Le livrable est une démo de conférence, pas un produit de production"
area: decisions
status: validated
updated: 2026-10-29
sources: [product/sources/product-description.pdf#p1, product/sources/product-description.pdf#p2, product/sources/product-description.pdf#p3, product/sources/product-description.pdf#p11]
links: [p-fn-vision, p-fn-scope, p-fn-risks-acceptance, p-rm-roadmap, p-rm-beyond, p-rm-open-questions, pdr-0004-mvp-three-acts, pdr-0005-frozen-fictional-dataset, pdr-0006-replay-fallback-must, adr-0008-ds-widgetbook-4-beta, adr-0002-orchestrator-backend, pdr-0029-local-docker-compose-hosting, pdr-0032-obs-video-fallback-a2ui-replay-act]
tags: [pdr, decision, scope, conference, demo]
decision_status: acceptée
decided_on: 2026-10-28
decided_by: "Benoît FONTAINE (porteur), via la fiche produit du 2026-10-28"
scope: mixte
supersedes: []
superseded_by: null
---
# PDR-0001 — Livrable : démo de conférence

> **En bref.** Genesis Canvas est une démo projetée pendant un talk Flutter GenUI, pas un produit livré à des utilisateurs. Ce cadrage justifie les données fictives, l'absence d'authentification et l'acceptation de briques expérimentales. Il place le risque principal sur la scène, pas sur la technique.

Part de l'assistant : mise en forme de la fiche. Aucune recommandation.

## Contexte
- Fiche § 1, tableau « Élément / Valeur » (p. 1) : « Type de livrable : Démo de conférence, pas un produit de production ».
- Le problème adressé est pédagogique : rendre visible le flux voix → agents → JSON A2UI → widgets Flutter, que les démos d'IA habituelles cachent (fiche § 1).
- Le message unique du talk : « L'agent ne génère pas du code, il génère de la donnée d'interface ; le développeur Flutter garde la main sur le rendu via son catalogue » (fiche § 1).

## Hypothèses
- ✅ Le public est composé de développeurs Flutter et de leads tech (fiche § 2, personas).
- ⚠️ Hypothèse non confirmée : durée de la démo de 8 à 10 minutes dans un talk de 40 minutes (fiche § 1 : « hypothèse à confirmer ») → [p-rm-open-questions](../roadmap/open-questions.md) (Q-06).
- ⚠️ Hypothèse non confirmée : le gabarit SDD du porteur ; la fiche suit « une structure SDD générique » (fiche § 1) → [p-rm-open-questions](../roadmap/open-questions.md) (Q-09).

## Options
Aucune alternative documentée dans la source. La fiche exclut seulement le « produit de production ».

## Décision
Le livrable est une **application de démonstration** dont le succès se mesure sur scène :
- 3 actes joués en direct sans incident ([pdr-0004-mvp-three-acts](pdr-0004-mvp-three-acts.md)) ;
- un mode secours toujours disponible ([pdr-0006-replay-fallback-must](pdr-0006-replay-fallback-must.md)) ;
- les critères d'acceptation et métriques de la fiche § 8 ([p-fn-risks-acceptance](../functional/risks-acceptance.md)).

## Raisons
- Fiche § 8 : « Le risque principal n'est pas technique, il est scénique : une démo vocale en direct sur le Wi-Fi d'une conférence. »
- Fiche § 1 : GenUI et A2UI sont expérimentales ; un produit de production ne pourrait pas s'appuyer dessus, une démo le peut à condition de figer les versions ([pdr-0010-pinned-experimental-versions](pdr-0010-pinned-experimental-versions.md)).
- Même logique que [adr-0008-ds-widgetbook-4-beta] côté knowledge : l'avance de phase est assumée parce que le projet est une démo de talk.

## Options écartées
- **Produit de production** : écarté explicitement par la fiche § 1. Corollaire, fiche § 3 « Hors périmètre » : authentification utilisateur, multi-utilisateur, persistance au-delà de la session.

## Conséquences
- **Fonctionnel** : périmètre volontairement étroit ([p-fn-scope](../functional/scope.md)) ; données fictives ([pdr-0005-frozen-fictional-dataset](pdr-0005-frozen-fictional-dataset.md)).
- **Architecture** : pas de gestion de comptes. ⚠️ Écart à arbitrer : AGENTS.md § 2 impose des JWT vérifiés par JWKS sur le backend, et [rt-ephemeral-keys] recommande un endpoint de session vocale protégé par l'auth utilisateur ; la fiche exclut l'authentification utilisateur. La façon de protéger le backend de la démo reste ouverte → [p-rm-open-questions](../roadmap/open-questions.md) (Q-15). Voir [p-ar-security](../architecture/security.md).
- **Qualité** : la Definition of Done est scénique (10 répétitions consécutives, réseau mobile, sono allumée) → [p-ar-quality](../architecture/quality.md), [p-ar-stage-runtime](../architecture/stage-runtime.md).
- **Roadmap** : jalon final = répétition générale puis talk ([p-rm-roadmap](../roadmap/roadmap.md)) ; tout passage vers un produit relève de [p-rm-beyond](../roadmap/beyond.md).

## Réexaminer si
- Le porteur veut réutiliser Genesis Canvas comme produit ou comme outil interne après le talk ([p-rm-beyond](../roadmap/beyond.md)).
- Une démo publique en libre accès (stand, site web) est envisagée : l'absence d'authentification devient alors un problème de sécurité et de coût (NFR-11).

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-28 | Acceptée dans la fiche produit (§ 1) | Benoît FONTAINE (porteur) |
| 2026-10-28 | Consignée en PDR | Assistant (mise en forme) |
| 2026-10-29 | Reconfirmée ; deux conséquences changent : le secours n'est plus un mode de l'app mais une vidéo gérée par le porteur ([pdr-0032](pdr-0032-obs-video-fallback-a2ui-replay-act.md)) ; l'écart JWT / pas d'auth est levé par le déploiement local sur `127.0.0.1` ([pdr-0029](pdr-0029-local-docker-compose-hosting.md)) | Assistant, sur parole du porteur : « C'est une démo, tout sera en local » |

Pas d'archive brute.
