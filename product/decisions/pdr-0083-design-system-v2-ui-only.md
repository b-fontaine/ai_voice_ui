---
id: pdr-0083-design-system-v2-ui-only
title: "PDR-0083 — Le design system du 2026-11-02 est la source de l'UI seulement ; 017 l'applique à l'app Flutter"
area: decisions
status: validated
updated: 2026-11-02
sources: [product/sources/design-system-2026-11-02/README.md, product/sources/design-system-2026-11-02/tokens.json, product/sources/design-system-2026-11-02/components/bundle.css, product/sources/product-description.pdf#p7, knowledge:ds-a11y-wcag-contrast, knowledge:ds-motion]
links: [pdr-0087-design-system-fidelity-no-24px-minimum, p-sources, p-ar-design-system, p-fn-mockups, p-fn-nfr, p-rm-backlog, p-rm-open-questions, pdr-0017-source-hierarchy-sheet-over-mockups, pdr-0062-standing-rule-sheet-wins-assistant-decides-ui-details, pdr-0072-design-ergonomics-013, pdr-0075-013-design-ergonomics-details-assistant-decided, pdr-0079-013-tokens-exception-to-adr-0005, pdr-0064-008-act2-transform-details-assistant-decided, pdr-0065-009-act3-interact-details-assistant-decided, pdr-0007-closed-catalog-stage-theme, pdr-0010-pinned-experimental-versions, pdr-0063-007-stage-ui-details-assistant-decided, adr-0005-ds-tokens-style-dictionary]
tags: [pdr, decision, design-system, ui, ux, 017]
decision_status: acceptée
decided_on: 2026-11-02
decided_by: "Benoît FONTAINE (porteur), conversation Claude Code, 2026-11-02"
scope: mixte
supersedes: []
superseded_by: null
---
# PDR-0083 — Le design system du 2026-11-02 est la source de l'UI seulement ; 017 l'applique à l'app Flutter

> **En bref.** Le porteur a fourni un design system repensé ([source](../sources/design-system-2026-11-02/README.md)). Il en précise la portée : il fournit l'**UI** ; l'application et `product/` gardent l'**UX** et les **règles métier**. La fonctionnalité **017** applique cet habillage à l'app, sans toucher au comportement, aux données ni au contrat A2UI. Décision de la main du porteur (assistant : mise en forme et consignation).

## Contexte
Le 2026-11-02, le porteur publie un artifact « Genesis Canvas » (version `1793632730-cd3c`) : tokens, 12 composants HTML/CSS d'exemple, mouvement. Ses exemples contiennent aussi des choix d'UX et de métier (appui long et reçu nominatif sur « Bloquer », règle « À risque » à marge < 0,1 pt, critique des deltas, ordre fixe des agents, nombre de verbatims, bande Décision vide, données d'exemple, messages du flux). 013 a déjà livré des tokens DTCG et un thème de scène ([p-ar-design-system](../architecture/design-system.md), [pdr-0075](pdr-0075-013-design-ergonomics-details-assistant-decided.md), [pdr-0079](pdr-0079-013-tokens-exception-to-adr-0005.md)).

## Hypothèses
- ✅ Portée confirmée par le porteur (voir Décision et Historique).
- ⚠️ Hypothèse non confirmée : plusieurs valeurs du design system vont contre NFR-05 (texte ≥ 24 px) → [Q-91](../roadmap/open-questions.md) (non bloquante) ; tranchée par D4.

## Options
1. **UI seulement (retenue)** : le design system habille l'app, l'UX et le métier restent ceux de l'app et de `product/`.
2. Suivre aussi l'UX et le métier de ses exemples : écartée par le porteur.

## Décision
- **D1 Portée.** Le design system du 2026-11-02 est la source de l'**UI** : tokens de couleur, typographie, espacements, rayons, ombres, mouvement, apparence des composants. L'application et `product/` restent la source de l'**UX** et des **règles métier** : les exemples du design system ne changent ni comportement ni donnée (liste du Contexte). Hiérarchie : la fiche produit fait foi ([pdr-0017](pdr-0017-source-hierarchy-sheet-over-mockups.md), [pdr-0062](pdr-0062-standing-rule-sheet-wins-assistant-decides-ui-details.md)) ; le design system **remplace les maquettes pour l'UI seulement** (les maquettes restent une illustration pour le reste).
- **D2 Fonctionnalité 017.** Elle applique cet habillage à l'app Flutter : thème (`SceneTheme`, unique `ThemeExtension`, RG-09) et tokens livrés par 013, styles de texte, ombres, animations nommées et durées, apparence des composants existants. Sans changer comportement, données ni contrat A2UI (catalogue fermé, [pdr-0007](pdr-0007-closed-catalog-stage-theme.md)).
- **D3 Contraintes constatées (pas de choix nouveau).** Polices : Space Grotesk et JetBrains Mono doivent être **embarquées** dans l'app (le `bundle.css` les charge depuis Google Fonts ; aucun téléchargement de police à l'exécution, build reproductible sur machine vierge, NFR-10 et [pdr-0010](pdr-0010-pinned-experimental-versions.md)) ; licence à vérifier par la boucle. Tailles : NFR-05 (≥ 24 px) l'emporte sur les tailles du design system inférieures (`label` 11, `data`, `body`, `button` 15, `ink-faint` ≥ 13) ; la façon de garder la hiérarchie est tranchée par D4 ([Q-91](../roadmap/open-questions.md)). `ink-faint` (3,9:1) reste conforme AA seulement à partir de 24 px (« grand texte », 3:1, [ds-a11y-wcag-contrast]).
- **D4 Tailles (Q-91, 2026-11-02).** Aucun texte de l'app ne passe sous 24 px (NFR-05 inchangée) : les tailles du design system sont relevées à 24 px minimum ; la hiérarchie passe par la graisse, la casse, la famille de police et la couleur. `ink-faint` reste utilisable puisque tout texte est ≥ 24 px (« grand texte », 3:1, [ds-a11y-wcag-contrast]). Choix du porteur : option « Tout à 24 px minimum (Recommandé) », libellé complet : « Les tailles du design system sont relevées à 24 px ; la hiérarchie passe par la graisse, la casse, la police et la couleur. C'est ce que la boucle fera par défaut. » La boucle montre le rendu en capture 1920×1080 ; le porteur le juge en répétition.

## Raisons
- Parole du porteur : l'UX et le métier restent dans l'app ; le design system n'apporte que l'UI.
- Évite qu'un exemple de composant (appui long, règle « À risque »…) soit pris pour une exigence, ce que [pdr-0017](pdr-0017-source-hierarchy-sheet-over-mockups.md) interdit déjà pour les maquettes.

## Options écartées
- Reprendre aussi l'UX des exemples : écartée par le porteur.

## Conséquences
Aucune PDR n'est marquée remplacée : aucun point de remplacement n'est univoque. Décisions d'UI touchées, **à trancher par la boucle à l'étape Définir de 017 sous pdr-0062** (réserves contestables, signalées dans `specs/progress.md`) :

| Décision | Point touché |
|---|---|
| [pdr-0072](pdr-0072-design-ergonomics-013.md), [pdr-0075](pdr-0075-013-design-ergonomics-details-assistant-decided.md) | D1 mise en page (rail 96 px, régie) et D2 cellules lisibles : l'habillage ne doit pas les défaire ; D3 apparition (200 ms, 150 ms, 8 px) : le design system propose 160 ms / 480 ms / 1,4 s et `gc-rise` (+10 px) ; D4 espacements et rayons « non tokenisés » : le design system en définit |
| [pdr-0079](pdr-0079-013-tokens-exception-to-adr-0005.md), [adr-0005](../../knowledge/decisions/adr-0005-ds-tokens-style-dictionary.md) | Les nouveaux tokens suivent le même mécanisme (constantes `SceneTokens`, empreinte) ; l'exception reste valable |
| [pdr-0064](pdr-0064-008-act2-transform-details-assistant-decided.md) D8 | Couleurs de séries par plateforme (palette sans couleur de statut, 3.3 en pointillés) contre « courante `signal`, précédente `baseline` pointillée, seuil `nogo` » du design system : à arbitrer entre UI et lisibilité des deux plateformes |
| [pdr-0065](pdr-0065-009-act3-interact-details-assistant-decided.md) | Couleurs et contours des boutons de la Barre d'actions (D7) : repris du design system, sans changer l'interaction |
| [pdr-0063](pdr-0063-007-stage-ui-details-assistant-decided.md) | Contour pointillé, indicateur d'acte, zone Rejeu : apparence seule |
| Hors périmètre de 017 | Appui long et reçu nominatif, règle « À risque », critique des deltas, ordre des agents, nombre de verbatims, bande Décision vide, données et messages d'exemple |

Documents : [p-sources](../sources/README.md), [p-ar-design-system](../architecture/design-system.md), [p-fn-mockups](../functional/mockups.md), [p-rm-backlog](../roadmap/backlog.md) (017), [p-rm-open-questions](../roadmap/open-questions.md) (Q-91).

## Réexaminer si
- Le porteur veut aussi reprendre l'UX ou le métier d'un exemple du design system.
- Le rendu à 24 px minimum écrase la hiérarchie typographique au jugé du porteur (D4 ; baisser NFR-05 ou excepter les étiquettes serait alors une nouvelle décision).

## Historique
| Date | Événement | Qui |
|---|---|---|
| 2026-11-02 | Acceptée sur la parole du porteur, conversation Claude Code : « Alors, ce n'est qu'un design system avec des exemples. L'application porte l'UX et les règles métier, le design system l'UI. Tu comprends ? » ; à la proposition de l'assistant (« Appliquer le design system se limite donc à son habillage : tokens, styles de texte, animations et apparence des composants dans le thème Flutter, sans toucher ni au comportement ni aux données. Dis-moi si tu veux que je confie ce travail à la boucle. »), le porteur répond : « oui, confie-le à la boucle ». | Benoît FONTAINE (porteur) |
| 2026-11-02 | Précision D4 (Q-91 tranchée), parole du porteur, conversation Claude Code, option choisie « Tout à 24 px minimum (Recommandé) » : « Les tailles du design system sont relevées à 24 px ; la hiérarchie passe par la graisse, la casse, la police et la couleur. C'est ce que la boucle fera par défaut. » Pas de nouvelle PDR : précision de la même décision. | Benoît FONTAINE (porteur) |
| 2026-11-02 | **Appliquée** par 017 (UI seulement, tailles ≥ 24 px) ; détails d'application tranchés par la boucle dans [pdr-0084](pdr-0084-017-design-system-ui-details-assistant-decided.md) ; `gate --full` vert, captures conformes. Pas de nouvelle décision. | Assistant (clôture de 017) |
| 2026-11-03 | D4 remplacé par [pdr-0087](pdr-0087-design-system-fidelity-no-24px-minimum.md) (le minimum de 24 px est retiré, NFR-05 suspendue ; Q-91 retranchée) ; D1 à D3 inchangés, sauf la phrase de D3 qui fait primer NFR-05 sur les tailles du design system. Remplacement partiel : `decision_status` inchangé. | Benoît FONTAINE (porteur), conversation Claude Code |

Pas d'archive brute.
