---
id: pdr-0010-pinned-experimental-versions
title: "PDR-0010 — Versions figées de Flutter, genui et genui_a2a ; pubspec.lock committé"
area: decisions
status: validated
updated: 2026-10-29
sources: [product/sources/product-description.pdf#p1, product/sources/product-description.pdf#p7, product/sources/product-description.pdf#p12, knowledge:genui-overview, knowledge:ma-package-versions, knowledge:adr-0008-ds-widgetbook-4-beta, knowledge:ds-widgetbook-4-spike]
links: [p-fn-nfr, p-ar-stack, p-ar-quality, p-rm-spikes, p-rm-open-questions, pdr-0001-conference-demo-deliverable, pdr-0011-adopt-knowledge-adrs, genui-overview, ma-package-versions, genui-migration-0-10, genui-a2a-connector, adr-0008-ds-widgetbook-4-beta, ds-widgetbook-4-spike, pdr-0018-a2ui-v09-genui-0-10-4]
tags: [pdr, decision, versions, reproducibility, genui, flutter]
decision_status: acceptée
decided_on: 2026-10-28
decided_by: "Benoît FONTAINE (porteur), via la fiche produit du 2026-10-28"
scope: technique
supersedes: []
superseded_by: null
---
# PDR-0010 — Versions expérimentales figées

> **En bref.** GenUI et A2UI sont expérimentales : les versions de Flutter, `genui` et `genui_a2a` sont figées et le `pubspec.lock` est committé. Un build propre sur machine vierge fait partie de la Definition of Done. Les numéros exacts restent à arrêter dans [p-ar-stack](../architecture/stack.md).

Part de l'assistant : mise en forme ; état des versions tiré de knowledge.

## Contexte
- Fiche § 1 (p. 1) : « GenUI et A2UI sont expérimentales : versions figées obligatoires. »
- Fiche § 5, NFR-10 (p. 7) : « Versions Flutter, genui et genui_a2a figées (pubspec.lock committé) », mesuré par « Build propre sur machine vierge ».
- Fiche § 8 (p. 12), DoD : « Build propre sur machine vierge à partir du dépôt et du pubspec.lock. »
- Knowledge : `genui` est en alpha (« likely to change ») ; 0.10.4 et `genui_a2a` 0.10.1 relevés le 2026-10-26 ; une refonte modulaire (`a2ui_core`, `a2ui_agent`, `a2ui_flutter`) est annoncée [genui-overview], [ma-package-versions].

## Hypothèses
- ✅ Flutter 3.47.8 a été exécuté avec succès dans le spike Widgetbook [ds-widgetbook-4-spike].
- ⚠️ Hypothèse non confirmée : versions exactes à figer (Flutter, `genui`, `genui_a2a`, `a2ui_core`). Info datée du 2026-10-26, à revérifier sur pub.dev avant ajout [ma-package-versions] → [p-ar-stack](../architecture/stack.md), [p-rm-open-questions](../roadmap/open-questions.md) (Q-25).
- ✅ Écart E3 levé le 2026-10-29 : A2UI v0.9 avec genui 0.10.4 → [pdr-0018](pdr-0018-a2ui-v09-genui-0-10-4.md) (Q-03 tranchée).

## Options
Aucune alternative documentée dans la source.

## Décision
- Versions **figées** pour Flutter, `genui` et `genui_a2a` ; `pubspec.lock` **committé**.
- Reproductibilité vérifiée par un build propre sur machine vierge (NFR-10).

## Raisons
- Fiche § 1 : briques expérimentales dont l'API peut casser entre versions.
- Même logique que [adr-0008-ds-widgetbook-4-beta] (version exacte sans `^`, montée de version dans une PR dédiée après lecture du changelog).

## Options écartées
Aucune alternative documentée dans la source.

## Conséquences
- **Stack** : [p-ar-stack](../architecture/stack.md) liste chaque version figée, sa date de relevé et son statut (alpha, bêta, stable). Les contraintes croisées sont à vérifier : `genui` 0.10.4 dépend de `a2ui_core ^0.1.0` [ma-package-versions] ; les paquets `genui_*` 0.7.x sont abandonnés [genui-migration-0-10].
- **Cohérence** : `widgetbook` est déjà figé à 4.0.0-beta.14 [adr-0008-ds-widgetbook-4-beta] ; il doit rester compatible avec la version de Flutter figée.
- **CI** : un job « build sur machine vierge » à partir du lock → [p-ar-quality](../architecture/quality.md).
- **Backend** : la fiche ne parle que des paquets Flutter. Étendre le gel aux modules Go (`go.sum`, version de Go) n'est **pas décidé** → [p-rm-open-questions](../roadmap/open-questions.md) (question à ajouter au registre).
- **Roadmap** : un gel de versions avant les répétitions (*version freeze*) ; toute montée ensuite est un risque → [p-rm-roadmap](../roadmap/roadmap.md).

## Réexaminer si
- Une version de `genui` corrige un bug bloquant pour la démo : montée ciblée, dans une PR dédiée, suivie d'une répétition complète.
- La refonte modulaire `a2ui_flutter` remplace `genui` avant le talk.

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-10-28 | Acceptée dans la fiche produit (§ 1, NFR-10) | Benoît FONTAINE (porteur) |
| 2026-10-28 | Consignée en PDR | Assistant (mise en forme) |
| 2026-10-29 | Hypothèse E3 levée : A2UI v0.9 avec genui 0.10.4 ([pdr-0018](pdr-0018-a2ui-v09-genui-0-10-4.md), décision contrainte) | Assistant |

Pas d'archive brute.
