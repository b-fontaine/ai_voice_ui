---
id: p-fn-vision
title: Vision et problème
area: functional
status: validated
updated: 2026-10-29
sources: [product/sources/product-description.pdf#p1]
links: [p-fn-personas-journey, p-fn-scope, p-fn-catalog, p-fn-screen, pdr-0001-conference-demo-deliverable, pdr-0002-desktop-platform, pdr-0003-use-case-release-copilot, pdr-0010-pinned-experimental-versions, p-rm-open-questions, genui-overview, genui-a2ui-overview, pdr-0027-talk-context-meetup-flutter-nantes, pdr-0028-linux-demo-machine]
tags: [vision, produit, talk, release-copilot]
---
# Genesis Canvas — vision et problème

**En bref.** Genesis Canvas est une démo de conférence Flutter desktop. La voix du speaker déclenche des agents A2A qui renvoient de l'UI déclarative A2UI, rendue en direct par GenUI. Le public voit l'interface **se construire**, pas seulement le résultat.

## Énoncé produit (fiche § 1, p. 1)

Genesis Canvas est une application Flutter desktop projetée en conférence. Elle construit des écrans sous les yeux du public à partir d'une commande vocale, via des agents A2A qui renvoient de l'UI déclarative A2UI rendue par GenUI.

## Problème adressé (fiche § 1)

| Constat | Conséquence |
|---|---|
| Les démos d'IA générative montrent un résultat fini. | Le public ne le distingue pas d'un écran codé à la main. |
| Le flux réel (voix → agents → JSON A2UI → widgets Flutter) reste invisible. | La valeur de GenUI n'est pas démontrée. |

## Message unique du talk (fiche § 1)

> « L'agent ne génère pas du code, il génère de la donnée d'interface ; le développeur Flutter garde la main sur le rendu via son catalogue. »

Ce message structure tout le produit :
- l'écran montre la **fabrication** à côté du résultat ([p-fn-screen](screen.md), [pdr-0008-single-screen-show-the-making](../decisions/pdr-0008-single-screen-show-the-making.md)) ;
- l'IA compose **uniquement** avec un catalogue fermé ([p-fn-catalog](catalog.md), [pdr-0007-closed-catalog-stage-theme](../decisions/pdr-0007-closed-catalog-stage-theme.md)).

## Cas d'usage métier : Release Copilot (fiche § 1)

Préparer la décision **go/no-go d'une release mobile** à partir des crashs, des avis des stores, du changelog et des captures. Raisons du choix : il parle à tout développeur Flutter et produit naturellement des écrans variés. Voir [pdr-0003-use-case-release-copilot](../decisions/pdr-0003-use-case-release-copilot.md).

## Cadre du livrable (fiche § 1, tableau)

| Élément | Valeur | Décision |
|---|---|---|
| Type de livrable | Démo de conférence, **pas** un produit de production | [pdr-0001](../decisions/pdr-0001-conference-demo-deliverable.md) |
| Plateforme | Flutter desktop, macOS prioritaire, Windows en secours, projeté en 1920×1080 — **remplacé** : Linux, machine du porteur | [pdr-0002](../decisions/pdr-0002-desktop-platform.md), remplacée par [pdr-0028](../decisions/pdr-0028-linux-demo-machine.md) |
| Durée cible de la démo | 8 à 10 min dans un talk de 40 min — talk réel : 45 min, Meetup Flutter Nantes, 2026-11-12 | [pdr-0027](../decisions/pdr-0027-talk-context-meetup-flutter-nantes.md) (Q-06, Q-12) |
| Statut des briques | GenUI et A2UI expérimentales : versions figées obligatoires | [pdr-0010](../decisions/pdr-0010-pinned-experimental-versions.md), [genui-overview], [genui-a2ui-overview] |

## Hypothèses à confirmer (fiche § 1)

La fiche signalait trois points non fixés (écart E5, [p-rm-open-questions](../roadmap/open-questions.md)) ; deux sont tranchés le 2026-10-29 :

| Hypothèse | Statut |
|---|---|
| Durée du talk | ✅ 45 min ([pdr-0027](../decisions/pdr-0027-talk-context-meetup-flutter-nantes.md)) |
| OS de la machine de démo | ✅ Linux ([pdr-0028](../decisions/pdr-0028-linux-demo-machine.md)) |
| Format du gabarit SDD du porteur | ⚠️ Hypothèse non confirmée (Q-09) ; la fiche suit une structure SDD générique (vision, personas, périmètre, exigences, BDD, NFR, architecture, risques) |

## Pour aller plus loin

- Qui regarde et ce qu'il doit retenir : [p-fn-personas-journey](personas-journey.md).
- Ce qui est dedans et dehors : [p-fn-scope](scope.md).
- Ce qui fait réussir le talk : [p-fn-risks-acceptance](risks-acceptance.md).
